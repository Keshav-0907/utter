import AppKit
import FoundationModels
import MLX

/// Owns AI cleanup: which model is chosen, downloads, loading, and running cleanup safely.
@MainActor
final class CleanupManager: ObservableObject {
    static let shared = CleanupManager()
    static let appleChoice = "apple"

    enum InstallState: Equatable {
        case notInstalled
        case downloading(DownloadProgress)
        case installed
        case failed(String)
    }

    enum AppleStatus: Equatable {
        case available
        case unavailable(String)
    }

    struct TestResult: Equatable {
        let output: String
        let seconds: Double
        /// False when the model's output was thrown away and the original text kept.
        let accepted: Bool
    }

    @Published var enabled = Settings.cleanupEnabled { didSet { Settings.cleanupEnabled = enabled } }
    /// "apple", a model id, or "" when nothing is chosen yet.
    @Published private(set) var choice = Settings.cleanupChoice { didSet { Settings.cleanupChoice = choice } }
    @Published private(set) var installs: [String: InstallState] = [:]
    @Published private(set) var appleStatus: AppleStatus = .unavailable("")
    @Published private(set) var isLoadingModel = false
    @Published private(set) var lastError: String?

    let chip: String
    let memoryGB: Double
    var recommended: CleanupModel { CleanupModel.recommended(memoryGB: memoryGB) }

    private var engine: CleanupEngine?
    private var engineChoice = ""
    private var downloads: [String: Task<Void, Never>] = [:]
    private var idleGeneration = 0
    /// Free the model's memory after this long without a dictation; it reloads while you speak.
    private let idleUnloadAfter: TimeInterval = 600

    private init() {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        chip = String(cString: buffer)
        memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824

        // Keep MLX from holding on to large amounts of freed GPU memory between dictations.
        MLX.GPU.set(cacheLimit: 64 * 1024 * 1024)

        for model in CleanupModel.catalog {
            installs[model.id] = ModelDownloader.isInstalled(model) ? .installed : .notInstalled
        }
        refreshApple()
        // The saved choice is kept even if it is not usable right now (Apple Intelligence still
        // getting ready, say); `isActive` checks usability each time, so it resumes by itself.
    }

    // MARK: State

    var freeDiskGB: Double {
        let values = try? ModelDownloader.modelsDirectory.deletingLastPathComponent().deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return Double(values?.volumeAvailableCapacityForImportantUsage ?? 0) / 1_000_000_000
    }

    func refreshApple() {
        switch AppleCleanupEngine.availability {
        case .available:
            appleStatus = .available
        case .unavailable(.appleIntelligenceNotEnabled):
            appleStatus = .unavailable("Turn on Apple Intelligence in System Settings to use it.")
        case .unavailable(.deviceNotEligible):
            appleStatus = .unavailable("This Mac does not support Apple Intelligence.")
        case .unavailable(.modelNotReady):
            appleStatus = .unavailable("macOS is still downloading it. Try again in a while.")
        case .unavailable:
            appleStatus = .unavailable("Not available on this Mac.")
        }
    }

    func isUsable(_ choice: String) -> Bool {
        if choice == Self.appleChoice { return appleStatus == .available }
        return installs[choice] == .installed
    }

    /// True when cleanup will actually run on the next dictation.
    var isActive: Bool { enabled && isUsable(choice) }

    var choiceName: String {
        if choice == Self.appleChoice { return "Apple Intelligence" }
        return CleanupModel.catalog.first { $0.id == choice }?.name ?? "None"
    }

    // MARK: Choosing, downloading, removing

    func use(_ newChoice: String) {
        guard isUsable(newChoice) else { return }
        choice = newChoice
        enabled = true
        engine = nil
        prepare()
    }

    /// Download a model; when `thenUse` is set it is selected and switched on as soon as it is ready.
    func download(_ model: CleanupModel, thenUse: Bool) {
        guard downloads[model.id] == nil else { return }
        installs[model.id] = .downloading(DownloadProgress(received: 0, total: Int64(model.sizeGB * 1_000_000_000)))
        downloads[model.id] = Task { [weak self] in
            do {
                try await ModelDownloader().download(model) { progress in
                    Task { @MainActor in
                        guard let self, case .downloading = self.installs[model.id] else { return }
                        self.installs[model.id] = .downloading(progress)
                    }
                }
                guard let self else { return }
                self.installs[model.id] = .installed
                if thenUse { self.use(model.id) }
            } catch {
                // A cancelled network request surfaces as URLError.cancelled, not CancellationError.
                let cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled
                self?.installs[model.id] = cancelled ? .notInstalled : .failed(error.localizedDescription)
            }
            self?.downloads[model.id] = nil
        }
    }

    func cancelDownload(_ model: CleanupModel) {
        downloads[model.id]?.cancel()
    }

    func remove(_ model: CleanupModel) {
        if choice == model.id {
            choice = ""
            engine = nil
        }
        ModelDownloader.remove(model)
        installs[model.id] = .notInstalled
    }

    // MARK: Running

    private func currentEngine() -> CleanupEngine? {
        guard isUsable(choice) else { return nil }
        if let engine, engineChoice == choice { return engine }
        let created: CleanupEngine
        if choice == Self.appleChoice {
            created = AppleCleanupEngine()
        } else if let model = CleanupModel.catalog.first(where: { $0.id == choice }) {
            created = MLXCleanupEngine(directory: ModelDownloader.directory(for: model))
        } else {
            return nil
        }
        engine = created
        engineChoice = choice
        return created
    }

    /// Load the model in the background. Called at launch and whenever a dictation starts,
    /// so the model is ready by the time you finish speaking.
    func prepare() {
        guard isActive, let engine = currentEngine() else { return }
        scheduleIdleUnload()
        isLoadingModel = true
        Task {
            do {
                try await engine.warmUp()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
            isLoadingModel = false
        }
    }

    private func scheduleIdleUnload() {
        idleGeneration += 1
        let generation = idleGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + idleUnloadAfter) { [weak self] in
            guard let self, self.idleGeneration == generation else { return }
            self.engine = nil
        }
    }

    /// Cleans a dictation. Always returns usable text: on any doubt, error or delay it returns the input.
    func clean(_ text: String) async -> String {
        guard isActive else { return text }
        return await run(text).output
    }

    /// Runs cleanup regardless of the on/off switch (for the "Try it" box) and reports what happened.
    func run(_ text: String) async -> TestResult {
        let started = Date()
        func result(_ output: String, accepted: Bool) -> TestResult {
            TestResult(output: output, seconds: Date().timeIntervalSince(started), accepted: accepted)
        }
        guard let engine = currentEngine() else { return result(text, accepted: false) }
        scheduleIdleUnload()

        // Whatever happens, the user gets text within the time limit: the original if need be.
        let outcome: CleanupPipeline.Outcome? = await withTaskGroup(of: CleanupPipeline.Outcome?.self) { group in
            group.addTask { await CleanupPipeline.run(text, engine: engine) }
            group.addTask {
                try? await Task.sleep(for: .seconds(8))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        guard let outcome else { return result(text, accepted: false) }
        return result(outcome.text, accepted: outcome.attempted == 0 || outcome.applied > 0)
    }
}
