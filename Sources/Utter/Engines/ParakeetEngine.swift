import AVFoundation
import FluidAudio

/// NVIDIA Parakeet TDT 0.6B v2 (English), run on-device with CoreML through FluidAudio.
/// Unlike Apple's engine it is not streaming: audio is collected while you speak and
/// transcribed in one pass on release.
final class ParakeetEngine: TranscriptionEngine {
    let id = "parakeet-v2"
    let displayName = "Parakeet (English)"
    let summary = "NVIDIA's open speech model, run on this Mac. Utter downloads it once, about 450 MB, then it works offline."
    var onProgress: (@Sendable (String) -> Void)?

    var inputFormat: AVAudioFormat? { manager == nil ? nil : Self.format }

    private static let version = AsrModelVersion.v2
    private var manager: AsrManager?

    static let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

    func availability() async -> EngineAvailability {
        let directory = AsrModels.defaultCacheDirectory(for: Self.version)
        return AsrModels.modelsExist(at: directory, version: Self.version) ? .ready : .needsDownload
    }

    func prepare() async throws {
        guard manager == nil else { return }
        let report = onProgress
        let models = try await AsrModels.downloadAndLoad(version: Self.version) { progress in
            switch progress.phase {
            case .listing:
                report?("Finding the model files…")
            case .downloading:
                report?("Downloading the model… \(Int(progress.fractionCompleted * 100))%")
            case .compiling:
                report?("Preparing the model for this Mac…")
            }
        }
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        // First inference is slow while CoreML specialises the model; do it now, not on the first dictation.
        var state = TdtDecoderState.make()
        _ = try? await manager.transcribe([Float](repeating: 0, count: 16_000), decoderState: &state)
        self.manager = manager
    }

    func startSession(onPartial: @escaping @Sendable (String) -> Void) async throws -> TranscriptionSession {
        guard let manager else { throw EngineError("Parakeet is not loaded yet") }
        return Session(manager: manager)
    }

    private final class Session: TranscriptionSession, @unchecked Sendable {
        let inputFormat = ParakeetEngine.format
        private let manager: AsrManager
        private let lock = NSLock()
        private var samples: [Float] = []

        init(manager: AsrManager) {
            self.manager = manager
            samples.reserveCapacity(16_000 * 30)
        }

        func feed(_ buffer: AVAudioPCMBuffer) {
            guard let channel = buffer.floatChannelData?[0] else { return }
            let chunk = UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))
            lock.withLock { samples.append(contentsOf: chunk) }
        }

        func finish() async throws -> String {
            var audio = lock.withLock { samples }
            // The model needs at least a second of audio; pad short clips with silence.
            if audio.count < 16_000 { audio.append(contentsOf: [Float](repeating: 0, count: 16_000 - audio.count)) }
            var state = TdtDecoderState.make()
            return try await manager.transcribe(audio, decoderState: &state).text
        }

        func cancel() async {
            lock.withLock { samples.removeAll() }
        }
    }
}
