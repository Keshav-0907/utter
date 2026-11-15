import AppKit
import Carbon.HIToolbox

enum HotkeyChoice: String, CaseIterable, Identifiable {
    case rightOption, rightCommand, fn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rightOption: return "Right Option"
        case .rightCommand: return "Right Command"
        case .fn: return "Fn (Globe)"
        }
    }

    var symbol: String {
        switch self {
        case .rightOption: return "⌥"
        case .rightCommand: return "⌘"
        case .fn: return "fn"
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .rightOption: return UInt16(kVK_RightOption)
        case .rightCommand: return UInt16(kVK_RightCommand)
        case .fn: return UInt16(kVK_Function)
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .rightOption: return .option
        case .rightCommand: return .command
        case .fn: return .function
        }
    }
}

/// Push-to-talk on a single modifier key, observed globally. Needs Accessibility permission.
final class HotkeyMonitor {
    var choice: HotkeyChoice
    var onDown: (() -> Void)?
    var onUp: (() -> Void)?
    /// Escape pressed (the receiver decides whether anything is in progress).
    var onCancel: (() -> Void)?
    /// Another key was pressed while the hotkey is held: the user is typing a shortcut, not dictating.
    var onChord: (() -> Void)?

    private var monitors: [Any] = []
    private var held = false
    private var pressedAt = Date()
    private var watchdog: Timer?
    /// A shortcut's second key follows the modifier almost at once. A key pressed later,
    /// well into a dictation, is a stray and must not throw the recording away.
    private let chordWindow: TimeInterval = 0.7

    private static let modifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]

    init(choice: HotkeyChoice) { self.choice = choice }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] in self?.handle($0) }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown {
            if event.keyCode == UInt16(kVK_Escape) {
                onCancel?()
            } else if held, !event.isARepeat, Date().timeIntervalSince(pressedAt) < chordWindow {
                onChord?()
            }
            return
        }

        let flags = event.modifierFlags.intersection(Self.modifiers)
        if !held {
            // Start only on a clean press: the hotkey alone, with no other modifier already down.
            guard event.keyCode == choice.keyCode, flags == choice.flag else { return }
            press()
        } else if event.keyCode == choice.keyCode || !flags.contains(choice.flag) {
            // While held, another event for the same key can only be its release. Checking the
            // key code as well as the flag matters when the twin key (e.g. Left Option) is also down.
            release()
        }
    }

    private func press() {
        held = true
        pressedAt = Date()
        onDown?()
        // Some contexts (password fields, the lock screen) swallow the release event.
        // Poll the real keyboard state so a recording can never be left running.
        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.held else { return }
            if !NSEvent.modifierFlags.contains(self.choice.flag) {
                NSLog("Utter: key release was missed; ending the hold from the keyboard state")
                self.release()
            }
        }
    }

    private func release() {
        guard held else { return }
        held = false
        watchdog?.invalidate()
        watchdog = nil
        onUp?()
    }
}
