import AppKit
import AVFoundation

/// Owns the dictation lifecycle.
///
/// Hold the key: record while held, insert on release.
/// Double-tap the key: keep recording hands-free; tap once more to insert.
/// Esc: throw the recording away.
@MainActor
final class DictationController {
    enum State { case idle, starting, recording, finishing }
    private enum Pending { case none, finish, discard }

    private(set) var state: State = .idle {
        didSet { app.isRecording = state == .starting || state == .recording }
    }
    var engine: TranscriptionEngine

    private let app = AppState.shared
    private let capture = AudioCapture()
    private let hud = HUD()
    private var session: TranscriptionSession?
    private var pending: Pending = .none
    private var startedAt = Date()

    /// Hands-free mode: recording continues with the key released.
    private var locked = false {
        didSet {
            app.isLocked = locked
            hud.locked(locked)
        }
    }
    /// Set after a short tap while we wait to see if a second tap follows.
    private var awaitingSecondTap = false
    private var tapGeneration = 0
    private var lockGeneration = 0

    private let tapMaxDuration = 0.30
    private let secondTapWindow = 0.35
    private let lockedMaxDuration = 600.0

    init(engine: TranscriptionEngine) { self.engine = engine }

    func prepareEngine() {
        let engine = engine
        app.engineReady = false
        app.engineStatus = "Loading model…"
        engine.onProgress = { [weak self] message in
            Task { @MainActor in
                guard let self, self.engine === engine, !self.app.engineReady else { return }
                self.app.engineStatus = message
            }
        }
        Task {
            do {
                try await engine.prepare()
                guard self.engine === engine else { return }
                app.engineReady = true
                app.engineStatus = "Ready"
            } catch {
                guard self.engine === engine else { return }
                app.engineStatus = "Could not load \(engine.displayName): \(error.localizedDescription)"
            }
        }
    }

    // MARK: Hotkey events

    func hotkeyDown() {
        switch state {
        case .idle:
            begin()
        case .starting, .recording:
            if awaitingSecondTap {
                // Second tap of a double-tap: go hands-free. Recording never stopped.
                awaitingSecondTap = false
                tapGeneration += 1
                locked = true
                armRecordingTimeout()
            } else if locked {
                // Tap while hands-free: done.
                stop(.finish)
            }
        case .finishing:
            break
        }
    }

    func hotkeyUp() {
        guard state == .starting || state == .recording, !locked else { return }
        let held = Date().timeIntervalSince(startedAt)
        if held < tapMaxDuration {
            guard Settings.doubleTapLock else {
                NSLog("Utter: recording dropped: key was tapped, not held")
                shortTap = true
                return stop(.discard, quiet: true)
            }
            // Could be the first half of a double-tap; keep recording briefly.
            awaitingSecondTap = true
            tapGeneration += 1
            let generation = tapGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + secondTapWindow) { [weak self] in
                guard let self, self.tapGeneration == generation, self.awaitingSecondTap else { return }
                self.awaitingSecondTap = false
                NSLog("Utter: recording dropped: key was tapped, not held")
                self.shortTap = true
                self.stop(.discard, quiet: true)
            }
        } else {
            stop(.finish)
        }
    }

    /// A normal key was pressed while the hotkey is held, e.g. Cmd+C or Option+4.
    /// That is a keyboard shortcut, not a dictation: drop the recording without a trace.
    func interruptedByShortcut() {
        guard state == .starting || state == .recording, !locked else { return }
        NSLog("Utter: recording dropped: another key was pressed with the hotkey (a shortcut)")
        stop(.discard, quiet: true)
    }

    /// Escape: throw the recording away.
    func cancel() {
        guard state == .starting || state == .recording else { return }
        NSLog("Utter: recording dropped: Esc")
        stop(.discard)
    }

    // MARK: Lifecycle

    private func begin() {
        guard app.micStatus == .authorized else {
            app.refreshPermissions()
            if app.micStatus == .authorized { begin() } else { hud.message("Microphone access needed") }
            return
        }
        guard app.engineReady else {
            hud.message("Speech model is still loading")
            return
        }
        state = .starting
        pending = .none
        locked = false
        awaitingSecondTap = false
        quietDiscard = false
        shortTap = false
        startedAt = Date()
        armRecordingTimeout()
        hud.listening()
        // Load the cleanup model while you speak so it is ready on release.
        CleanupManager.shared.prepare()

        // Open the microphone first and hold the audio until the session exists; creating the
        // session takes a moment and would otherwise swallow the first word.
        let relay = AudioRelay()
        let earlyFormat = engine.inputFormat
        if let earlyFormat {
            do {
                try startCapture(format: earlyFormat, relay: relay)
            } catch {
                Task { await fail(error) }
                return
            }
        }

        Task {
            do {
                let session = try await engine.startSession { [weak self] partial in
                    Task { @MainActor in self?.hud.partial(partial) }
                }
                self.session = session
                if earlyFormat == nil || session.inputFormat != earlyFormat {
                    capture.stop()
                    let fresh = AudioRelay()
                    fresh.attach(session)
                    try startCapture(format: session.inputFormat, relay: fresh)
                } else {
                    relay.attach(session)
                }
                state = .recording
                switch pending {
                case .finish: await finish()
                case .discard: await discard()
                case .none: break
                }
            } catch {
                await fail(error)
            }
        }
    }

    private func startCapture(format: AVAudioFormat, relay: AudioRelay) throws {
        try capture.start(
            format: format,
            onBuffer: { relay.feed($0) },
            onLevel: { [weak self] level in
                Task { @MainActor in self?.hud.level(CGFloat(level)) }
            }
        )
    }

    private var quietDiscard = false
    /// The key was let go too quickly to be a dictation; say so instead of vanishing.
    private var shortTap = false

    private func stop(_ action: Pending, quiet: Bool = false) {
        awaitingSecondTap = false
        tapGeneration += 1
        lockGeneration += 1
        if action == .discard { quietDiscard = quiet }
        switch state {
        case .starting:
            pending = action
        case .recording:
            Task {
                if action == .finish { await finish() } else { await discard() }
            }
        default:
            break
        }
    }

    /// Never leave the microphone open indefinitely, whether hands-free mode was forgotten
    /// or a key release was missed.
    private func armRecordingTimeout() {
        lockGeneration += 1
        let generation = lockGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + lockedMaxDuration) { [weak self] in
            guard let self, self.lockGeneration == generation else { return }
            guard self.state == .starting || self.state == .recording else { return }
            NSLog("Utter: recording ended by the 10-minute limit")
            self.stop(.finish)
        }
    }

    private func discard() async {
        guard state == .recording else { return }
        state = .finishing
        capture.stop()
        await session?.cancel()
        if shortTap {
            hud.message("Hold the key while you speak", for: 1.4)
        } else if quietDiscard {
            hud.hide()
        } else {
            hud.message("Cancelled", for: 0.8)
        }
        shortTap = false
        end()
    }

    private func finish() async {
        guard state == .recording, let session else { return }
        state = .finishing
        capture.stop()
        let released = Date()
        let audioSeconds = released.timeIntervalSince(startedAt)

        hud.processing()
        do {
            let raw = try await session.finish()
            let ruled = TextCleaner.clean(raw, removeFillers: Settings.removeFillers)
            let text = ruled.isEmpty ? ruled : await CleanupManager.shared.clean(ruled)
            let ms = Int(Date().timeIntervalSince(released) * 1000)
            NSLog("Utter: %.1f s of audio finalized in %d ms", audioSeconds, ms)
            if text.isEmpty {
                hud.message("Didn't catch that", for: 1.2)
            } else {
                TextInserter.insert(text + " ")
                app.recordDictation(HistoryEntry(
                    text: text, date: Date(), audioSeconds: audioSeconds, latencyMs: ms,
                    original: text == ruled ? nil : ruled))
                hud.hide()
            }
            end()
        } catch {
            await fail(error)
        }
    }

    private func fail(_ error: Error) async {
        NSLog("Utter: dictation failed: %@", String(describing: error))
        capture.stop()
        await session?.cancel()
        hud.message("Something went wrong", for: 2.0)
        app.engineStatus = error.localizedDescription
        end()
    }

    private func end() {
        session = nil
        pending = .none
        locked = false
        state = .idle
    }
}
