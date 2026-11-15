import AVFoundation

enum EngineAvailability: Equatable {
    case ready
    case needsDownload
    case unavailable(String)
}

/// A speech-to-text backend. Add a new model by implementing this protocol
/// and registering it in `EngineRegistry.all`.
protocol TranscriptionEngine: AnyObject {
    var id: String { get }
    var displayName: String { get }
    /// One or two plain sentences shown under the model picker.
    var summary: String { get }
    /// Receives plain-language status while `prepare()` downloads or loads the model.
    var onProgress: (@Sendable (String) -> Void)? { get set }

    /// The audio format sessions expect, known once `prepare()` has finished. Lets the
    /// microphone start before the session exists, so the first word is not lost.
    var inputFormat: AVAudioFormat? { get }

    func availability() async -> EngineAvailability

    /// Download assets if needed and warm the model so the first dictation is fast.
    func prepare() async throws

    /// Begin one dictation. `onPartial` receives the running transcript (any thread).
    func startSession(onPartial: @escaping @Sendable (String) -> Void) async throws -> TranscriptionSession
}

/// One push-to-talk utterance. Streaming engines transcribe as audio arrives;
/// batch engines can simply collect buffers and transcribe in `finish()`.
protocol TranscriptionSession: AnyObject {
    /// Audio must be delivered in this format.
    var inputFormat: AVAudioFormat { get }

    /// Called from the audio thread.
    func feed(_ buffer: AVAudioPCMBuffer)

    /// End of audio; returns the final transcript.
    func finish() async throws -> String

    func cancel() async
}

/// Holds microphone audio that arrives before the transcription session is ready,
/// then passes everything through in order.
final class AudioRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [AVAudioPCMBuffer] = []
    private var session: TranscriptionSession?

    func feed(_ buffer: AVAudioPCMBuffer) {
        lock.withLock {
            if let session { session.feed(buffer) } else { pending.append(buffer) }
        }
    }

    func attach(_ session: TranscriptionSession) {
        lock.withLock {
            for buffer in pending { session.feed(buffer) }
            pending.removeAll()
            self.session = session
        }
    }
}

enum EngineRegistry {
    static let all: [TranscriptionEngine] = [
        AppleSpeechEngine(),
        ParakeetEngine(),
        // Future: WhisperEngine(model: "small.en"), ...
    ]

    static func engine(id: String) -> TranscriptionEngine {
        all.first { $0.id == id } ?? all[0]
    }
}

struct EngineError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
