import AVFoundation
import Speech

/// Apple's on-device SpeechAnalyzer / SpeechTranscriber (macOS 26+). No download
/// managed by us: the OS owns the model assets.
final class AppleSpeechEngine: TranscriptionEngine {
    let id = "apple-speech"
    let displayName = "Apple Speech (built-in)"
    let summary = "Built into macOS. Nothing to download, and words appear as you speak."
    var onProgress: (@Sendable (String) -> Void)?

    private var locale: Locale?
    private var format: AVAudioFormat?
    var inputFormat: AVAudioFormat? { format }

    private static let options = SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)

    private func resolveLocale() async -> Locale {
        if let locale { return locale }
        var resolved = Locale(identifier: "en-US")
        for candidate in [Locale.current, Locale(identifier: "en-US")]
        where candidate.language.languageCode?.identifier == "en" {
            if let match = await SpeechTranscriber.supportedLocale(equivalentTo: candidate) {
                resolved = match
                break
            }
        }
        locale = resolved
        return resolved
    }

    private func makeTranscriber(_ locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
    }

    func availability() async -> EngineAvailability {
        guard SpeechTranscriber.isAvailable else {
            return .unavailable("SpeechTranscriber is not available on this Mac")
        }
        let transcriber = makeTranscriber(await resolveLocale())
        switch await AssetInventory.status(forModules: [transcriber]) {
        case .installed: return .ready
        case .supported, .downloading: return .needsDownload
        case .unsupported: return .unavailable("Locale not supported")
        @unknown default: return .unavailable("Unknown asset status")
        }
    }

    func prepare() async throws {
        guard SpeechTranscriber.isAvailable else {
            throw EngineError("SpeechTranscriber is not available on this Mac")
        }
        let locale = await resolveLocale()
        let transcriber = makeTranscriber(locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        // Load the model once; `.processLifetime` keeps it in memory for later sessions.
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: Self.options)
        try await analyzer.prepareToAnalyze(in: format)
        await analyzer.cancelAndFinishNow()
    }

    func startSession(onPartial: @escaping @Sendable (String) -> Void) async throws -> TranscriptionSession {
        let locale = await resolveLocale()
        let transcriber = makeTranscriber(locale)
        if format == nil {
            format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        }
        guard let format else { throw EngineError("No compatible audio format (speech assets missing?)") }
        return try await AppleSpeechSession(transcriber: transcriber, format: format, onPartial: onPartial)
    }

    var resolvedLocaleIdentifier: String? { locale?.identifier }

    private final class AppleSpeechSession: TranscriptionSession {
        let inputFormat: AVAudioFormat
        private let analyzer: SpeechAnalyzer
        private let input: AsyncStream<AnalyzerInput>.Continuation
        private let results: Task<String, Error>

        init(transcriber: SpeechTranscriber, format: AVAudioFormat, onPartial: @escaping @Sendable (String) -> Void) async throws {
            inputFormat = format
            analyzer = SpeechAnalyzer(modules: [transcriber], options: AppleSpeechEngine.options)
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            input = continuation

            results = Task {
                var finalized = ""
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        finalized += text
                        onPartial(finalized)
                    } else {
                        onPartial(finalized + text)
                    }
                }
                return finalized
            }
            try await analyzer.start(inputSequence: stream)
        }

        func feed(_ buffer: AVAudioPCMBuffer) {
            input.yield(AnalyzerInput(buffer: buffer))
        }

        func finish() async throws -> String {
            input.finish()
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            return try await results.value
        }

        func cancel() async {
            input.finish()
            await analyzer.cancelAndFinishNow()
            results.cancel()
        }
    }
}
