import AppKit
import ApplicationServices
import AVFoundation
import ServiceManagement

struct HistoryEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    let text: String
    let date: Date
    let audioSeconds: Double
    let latencyMs: Int
    /// The text before AI cleanup, kept only when cleanup changed it.
    var original: String?

    var wordCount: Int { text.split(whereSeparator: \.isWhitespace).count }
}

/// Lifetime totals. Kept separately from history so they survive clearing or disabling it.
struct Stats: Codable, Equatable {
    var words = 0
    var seconds = 0.0
    var dictations = 0
    /// Words per calendar day, keyed "yyyy-MM-dd".
    var daily: [String: Int] = [:]

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func key(_ date: Date) -> String { dayFormatter.string(from: date) }

    mutating func record(words count: Int, seconds duration: Double, on date: Date) {
        words += count
        seconds += duration
        dictations += 1
        daily[Self.key(date), default: 0] += count
    }

    /// Speaking pace across everything dictated so far.
    var wordsPerMinute: Int { seconds > 1 ? Int((Double(words) / (seconds / 60)).rounded()) : 0 }

    var today: Int { daily[Self.key(Date())] ?? 0 }

    /// Consecutive days with at least one dictation, counting back from today (or yesterday).
    var streak: Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date())
        if (daily[Self.key(day)] ?? 0) == 0 {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while (daily[Self.key(day)] ?? 0) > 0 {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    var lastWeek: [(day: Date, words: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return (day, daily[Self.key(day)] ?? 0)
        }
    }
}

/// Observable app state shared by the window, the menu and the dictation pipeline.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var engineStatus = "Starting…"
    @Published var engineReady = false
    @Published var isRecording = false
    @Published var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @Published var axTrusted = AXIsProcessTrusted()
    @Published private(set) var history: [HistoryEntry] = []
    @Published private(set) var stats = Stats()
    @Published var isLocked = false

    @Published var hotkey = Settings.hotkey { didSet { Settings.hotkey = hotkey; onHotkeyChange?(hotkey) } }
    @Published var engineID = Settings.engineID { didSet { Settings.engineID = engineID; onEngineChange?(engineID) } }
    @Published var removeFillers = Settings.removeFillers { didSet { Settings.removeFillers = removeFillers } }
    @Published var showLiveText = Settings.showLiveText { didSet { Settings.showLiveText = showLiveText } }
    @Published var saveHistory = Settings.saveHistory { didSet { Settings.saveHistory = saveHistory } }
    @Published var doubleTapLock = Settings.doubleTapLock { didSet { Settings.doubleTapLock = doubleTapLock } }
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Utter: launch at login failed: %@", String(describing: error))
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    var onHotkeyChange: ((HotkeyChoice) -> Void)?
    var onEngineChange: ((String) -> Void)?
    var onTrusted: (() -> Void)?

    var permissionsOK: Bool { micStatus == .authorized && axTrusted }

    private var permissionTimer: Timer?

    private init() {
        loadHistory()
        loadStats()
    }

    // MARK: Stats

    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: "stats"),
           let saved = try? JSONDecoder().decode(Stats.self, from: data) {
            stats = saved
            return
        }
        // First run with stats: seed from whatever history exists.
        for entry in history {
            stats.record(words: entry.wordCount, seconds: entry.audioSeconds, on: entry.date)
        }
        persistStats()
    }

    private func persistStats() {
        if let data = try? JSONEncoder().encode(stats) { UserDefaults.standard.set(data, forKey: "stats") }
    }

    func recordDictation(_ entry: HistoryEntry) {
        stats.record(words: entry.wordCount, seconds: entry.audioSeconds, on: entry.date)
        persistStats()
        addHistory(entry)
    }

    func resetStats() {
        stats = Stats()
        persistStats()
    }

    // MARK: Permissions

    func refreshPermissions() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let trusted = AXIsProcessTrusted()
        if trusted, !axTrusted { onTrusted?() }
        axTrusted = trusted
    }

    /// Poll until everything is granted (there is no notification for Accessibility trust).
    func watchPermissions() {
        refreshPermissions()
        guard !permissionsOK, permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refreshPermissions()
                if self.permissionsOK {
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                }
            }
        }
    }

    func requestMicrophone() {
        if micStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in AppState.shared.refreshPermissions() }
            }
        } else {
            open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        }
    }

    func requestAccessibility() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }

    // MARK: History (stored locally only)

    private var historyURL: URL {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Utter", isDirectory: true)
        // Carry data over from the app's earlier working names.
        for legacyName in ["Diction", "Murmur"] where !fm.fileExists(atPath: dir.path) {
            let legacy = support.appendingPathComponent(legacyName, isDirectory: true)
            if fm.fileExists(atPath: legacy.path) { try? fm.moveItem(at: legacy, to: dir) }
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL),
              let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        history = entries
    }

    private func persistHistory() {
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: historyURL, options: .atomic)
        }
    }

    private func addHistory(_ entry: HistoryEntry) {
        guard saveHistory else { return }
        history.insert(entry, at: 0)
        if history.count > 300 { history.removeLast(history.count - 300) }
        persistHistory()
    }

    func deleteHistory(_ entry: HistoryEntry) {
        history.removeAll { $0.id == entry.id }
        persistHistory()
    }

    func clearHistory() {
        history = []
        persistHistory()
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
