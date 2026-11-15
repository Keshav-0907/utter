import AppKit
import Charts
import SwiftUI

// Design rules for this window (from Apple's Liquid Glass guidance):
// glass is for the navigation layer only (the system sidebar and toolbar provide it);
// content sits on solid system surfaces, uses the user's accent colour, and no decoration.

private extension View {
    /// The quiet grouped surface System Settings uses for related content.
    func grouped(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Home

/// A key that visibly presses down while you dictate.
private struct Keycap: View {
    let choice: HotkeyChoice
    let pressed: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(choice.symbol).font(.system(size: 24, weight: .medium))
            Text(choice == .fn ? "globe" : "right").font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(pressed ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .frame(width: 68, height: 64)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(pressed ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(nsColor: .controlBackgroundColor)))
                .shadow(color: .black.opacity(pressed ? 0.05 : 0.18), radius: pressed ? 0.5 : 1.5, y: pressed ? 0.5 : 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: pressed ? 0 : 1)
        }
        .offset(y: pressed ? 2 : 0)
        .animation(.easeOut(duration: 0.1), value: pressed)
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeView: View {
    @ObservedObject var state: AppState
    let showHistory: () -> Void
    @State private var scratch = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !state.permissionsOK { setup }
                hero
                stats
                week
                if state.history.count < 3 { tryIt } else { recent }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Home")
    }

    private var hero: some View {
        HStack(spacing: 20) {
            Keycap(choice: state.hotkey, pressed: state.isRecording)
            VStack(alignment: .leading, spacing: 6) {
                Text(state.isRecording
                    ? (state.isLocked ? "Listening hands-free" : "Listening")
                    : "Hold \(state.hotkey.title) to dictate")
                    .font(.system(size: 22, weight: .semibold))
                Text(heroDetail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var heroDetail: String {
        if state.isRecording {
            return state.isLocked ? "Tap \(state.hotkey.title) to insert, or press Esc to cancel." : "Release to insert, or press Esc to cancel."
        }
        if !state.engineReady { return state.engineStatus }
        return state.doubleTapLock
            ? "Release to insert the text at your cursor. Double-tap to keep listening without holding."
            : "Release to insert the text at your cursor."
    }

    private var stats: some View {
        HStack(spacing: 16) {
            Stat(value: state.stats.words.formatted(.number.notation(.compactName)), label: "Words")
            Divider().frame(height: 40)
            Stat(value: state.stats.wordsPerMinute > 0 ? "\(state.stats.wordsPerMinute)" : "–", label: "Words per minute")
            Divider().frame(height: 40)
            Stat(value: state.stats.today.formatted(), label: "Today")
            Divider().frame(height: 40)
            Stat(value: "\(state.stats.streak)", label: state.stats.streak == 1 ? "Day in a row" : "Days in a row")
        }
        .grouped(padding: 18)
        .animation(.snappy, value: state.stats)
    }

    private var week: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This week").font(.headline)
            Chart(state.stats.lastWeek, id: \.day) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("Words", item.words),
                    width: .ratio(0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .foregroundStyle(Color.accentColor)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color(nsColor: .separatorColor).opacity(0.6))
                    AxisValueLabel().foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 120)
            .grouped()
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent").font(.headline)
                Spacer()
                Button("Show All", action: showHistory).buttonStyle(.link)
            }
            VStack(spacing: 0) {
                let items = Array(state.history.prefix(3))
                ForEach(items) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(entry.text).lineLimit(2)
                        Spacer(minLength: 8)
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    if entry.id != items.last?.id { Divider().padding(.leading, 16) }
                }
            }
            .grouped(padding: 0)
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try it").font(.headline)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $scratch)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                if scratch.isEmpty {
                    Text("Click here, hold \(state.hotkey.title), and say something.")
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 72)
            .padding(10)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(nsColor: .separatorColor)))
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Finish setting up").font(.headline)
            VStack(spacing: 12) {
                permissionRow(
                    granted: state.micStatus == .authorized,
                    title: "Microphone",
                    detail: "Lets Utter hear you while you dictate.",
                    action: state.micStatus == .notDetermined ? "Allow" : "Open Settings",
                    perform: state.requestMicrophone
                )
                Divider()
                permissionRow(
                    granted: state.axTrusted,
                    title: "Accessibility",
                    detail: "Lets Utter detect the key and type into other apps.",
                    action: "Open Settings",
                    perform: state.requestAccessibility
                )
            }
            .grouped()
        }
    }

    private func permissionRow(granted: Bool, title: String, detail: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted { Button(action, action: perform) }
        }
    }
}

// MARK: - History

private struct HistoryRow: View {
    let entry: HistoryEntry
    let copy: () -> Void
    let delete: () -> Void
    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Text("\(entry.date.formatted(.relative(presentation: .named))), \(entry.wordCount) words")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Button {
                    copy()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .help("Copy")
                Button(action: delete) { Image(systemName: "trash") }.help("Delete")
            }
            .buttonStyle(.borderless)
            .opacity(hovering || copied ? 1 : 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy", action: copy)
            Button("Delete", role: .destructive, action: delete)
        }
    }
}

private struct HistoryView: View {
    @ObservedObject var state: AppState
    @State private var confirmClear = false
    @State private var query = ""

    private var entries: [HistoryEntry] {
        query.isEmpty ? state.history : state.history.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if state.history.isEmpty {
                ContentUnavailableView(
                    state.saveHistory ? "No dictations yet" : "History is off",
                    systemImage: "clock",
                    description: Text(state.saveHistory
                        ? "Hold \(state.hotkey.title) and speak. What you dictate is kept here, on this Mac only."
                        : "Turn on “Keep dictation history” in Settings to save what you dictate.")
                )
            } else if entries.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(entries) { entry in
                    HistoryRow(entry: entry, copy: { state.copy(entry.text) }, delete: { state.deleteHistory(entry) })
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("History")
        .searchable(text: $query, prompt: "Search dictations")
        .toolbar {
            ToolbarItem {
                Button("Clear History…", systemImage: "trash") { confirmClear = true }
                    .disabled(state.history.isEmpty)
                    .help("Delete all saved dictations")
            }
        }
        .confirmationDialog("Delete all saved dictations?", isPresented: $confirmClear) {
            Button("Delete All", role: .destructive) { state.clearHistory() }
        } message: {
            Text("Your statistics are kept.")
        }
    }
}

// MARK: - Cleanup

private struct ModelRow: View {
    @ObservedObject var cleanup: CleanupManager
    let model: CleanupModel
    @State private var confirmRemove = false

    var body: some View {
        let state = cleanup.installs[model.id] ?? .notInstalled
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                    if model == cleanup.recommended {
                        Text("Suggested for this Mac")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(detail(state)).font(.callout).foregroundStyle(.secondary)
                if case .downloading(let progress) = state {
                    ProgressView(value: progress.fraction).controlSize(.small).padding(.top, 2)
                }
            }
            Spacer(minLength: 12)
            controls(state)
        }
        .confirmationDialog("Remove \(model.name)?", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive) { cleanup.remove(model) }
        } message: {
            Text("This frees \(size(model.sizeGB)). You can download it again later.")
        }
    }

    private func size(_ gb: Double) -> String {
        gb < 1 ? "\(Int((gb * 1000).rounded())) MB" : String(format: "%.1f GB", gb)
    }

    private func detail(_ state: CleanupManager.InstallState) -> String {
        switch state {
        case .downloading(let progress):
            let received = ByteCountFormatter.string(fromByteCount: progress.received, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: progress.total, countStyle: .file)
            return "Downloading \(received) of \(total)"
        case .failed(let message):
            return "Download failed: \(message)"
        case .installed:
            return "\(model.summary) Installed, \(size(model.sizeGB))."
        case .notInstalled:
            return "\(model.summary) \(size(model.sizeGB)) download."
        }
    }

    @ViewBuilder
    private func controls(_ state: CleanupManager.InstallState) -> some View {
        switch state {
        case .notInstalled:
            Button("Download") { cleanup.download(model, thenUse: true) }
        case .failed:
            Button("Try Again") { cleanup.download(model, thenUse: true) }
        case .downloading:
            Button("Cancel") { cleanup.cancelDownload(model) }
        case .installed:
            if cleanup.choice == model.id {
                Label("In use", systemImage: "checkmark").foregroundStyle(.secondary)
            } else {
                Button("Use") { cleanup.use(model.id) }
            }
            Button("Remove", systemImage: "trash") { confirmRemove = true }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Remove this model from your Mac")
        }
    }
}

private struct CleanupView: View {
    @ObservedObject var cleanup: CleanupManager
    @State private var sample = "so um send the report to rahul no actually send it to priya by three thirty tomorrow"
    @State private var result: CleanupManager.TestResult?
    @State private var running = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $cleanup.enabled) {
                    Text("Clean up dictation with AI")
                    Text("Fixes punctuation, drops false starts, keeps only your correction when you change your mind, and writes numbers and times properly.")
                }
                .disabled(!cleanup.isUsable(cleanup.choice))
                LabeledContent("You say") {
                    Text("send it to rahul no actually send it to priya").foregroundStyle(.secondary)
                }
                LabeledContent("Utter types") { Text("Send it to Priya.") }
            } footer: {
                Text(status).frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                appleRow
                ForEach(CleanupModel.catalog) { model in
                    ModelRow(cleanup: cleanup, model: model)
                }
            } header: {
                Text("Model")
            } footer: {
                Text("This Mac has an \(cleanup.chip) chip, \(Int(cleanup.memoryGB.rounded())) GB of memory and \(Int(cleanup.freeDiskGB)) GB of free space. Downloading saves the model's files from Hugging Face into Utter's folder on this Mac. It happens once; after that cleanup works offline and nothing you say leaves your Mac. Remove a model at any time to get the space back.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section("Try it") {
                TextField("Something you might say", text: $sample, axis: .vertical)
                    .lineLimit(2...4)
                    .labelsHidden()
                LabeledContent {
                    Button(running ? "Cleaning…" : "Clean Up") {
                        running = true
                        result = nil
                        Task {
                            result = await cleanup.run(sample)
                            running = false
                        }
                    }
                    .disabled(running || !cleanup.isUsable(cleanup.choice))
                } label: {
                    if let result {
                        Text(result.accepted ? result.output : "Left unchanged")
                        Text(result.accepted
                            ? String(format: "Took %.1f seconds.", result.seconds)
                            : "The model's answer strayed too far from what was said, so Utter kept the original.")
                    } else {
                        Text("Result appears here").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Cleanup")
        .onAppear { cleanup.refreshApple() }
    }

    private var status: String {
        if !cleanup.isUsable(cleanup.choice), cleanup.installs.values.contains(.installed) || cleanup.appleStatus == .available {
            return "Press Use on a model below to turn this on."
        }
        if !cleanup.isUsable(cleanup.choice) {
            return "Choose a model below to turn this on. \(cleanup.recommended.name) is a good fit for this Mac: press Download and Utter sets everything up."
        }
        if cleanup.isLoadingModel { return "Loading \(cleanup.choiceName)…" }
        if let error = cleanup.lastError { return "Could not load \(cleanup.choiceName): \(error)" }
        return cleanup.enabled ? "On, using \(cleanup.choiceName)." : "Off. Dictation is typed as heard."
    }

    private var appleRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Intelligence")
                switch cleanup.appleStatus {
                case .available:
                    Text("Built into macOS. Nothing to download.").font(.callout).foregroundStyle(.secondary)
                case .unavailable(let reason):
                    Text("Built into macOS. \(reason)").font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            if cleanup.appleStatus == .available {
                if cleanup.choice == CleanupManager.appleChoice {
                    Label("In use", systemImage: "checkmark").foregroundStyle(.secondary)
                } else {
                    Button("Use") { cleanup.use(CleanupManager.appleChoice) }
                }
            } else {
                Button("Open Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

// MARK: - Settings

private struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Dictation") {
                Picker("Hold to dictate", selection: $state.hotkey) {
                    ForEach(HotkeyChoice.allCases) { Text($0.title).tag($0) }
                }
                Toggle(isOn: $state.doubleTapLock) {
                    Text("Double-tap for hands-free")
                    Text("Keeps listening until you tap the key again.")
                }
                Toggle(isOn: $state.removeFillers) {
                    Text("Remove filler words")
                    Text("Leaves out “um” and “uh”.")
                }
            }
            Section {
                Picker("Model", selection: $state.engineID) {
                    ForEach(EngineRegistry.all, id: \.id) { Text($0.displayName).tag($0.id) }
                }
            } header: {
                Text("Speech model")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(EngineRegistry.engine(id: state.engineID).summary)
                    if !state.engineReady { Text(state.engineStatus).foregroundStyle(.primary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section("While listening") {
                Toggle(isOn: $state.showLiveText) {
                    Text("Show words as you speak")
                    Text("Adds the live transcript to the indicator at the bottom of the screen.")
                }
            }
            Section("General") {
                Toggle("Open at login", isOn: $state.launchAtLogin)
                Toggle(isOn: $state.saveHistory) {
                    Text("Keep dictation history")
                    Text("Saved on this Mac only.")
                }
                LabeledContent {
                    Button("Reset…") { confirmReset = true }
                } label: {
                    Text("Statistics")
                    Text("\(state.stats.dictations.formatted()) dictations counted.")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .confirmationDialog("Reset all statistics?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { state.resetStats() }
        }
    }
}

// MARK: - Root

private enum Page: String, CaseIterable, Identifiable {
    case home = "Home", history = "History", cleanup = "Cleanup", settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .history: return "clock"
        case .cleanup: return "wand.and.sparkles"
        case .settings: return "gearshape"
        }
    }
}

private struct RootView: View {
    @ObservedObject var state: AppState
    @State var page: Page? = .home

    var body: some View {
        NavigationSplitView {
            List(Page.allCases, selection: $page) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            switch page ?? .home {
            case .home: HomeView(state: state, showHistory: { page = .history })
            case .history: HistoryView(state: state)
            case .cleanup: CleanupView(cleanup: CleanupManager.shared)
            case .settings: SettingsView(state: state)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

/// The main window. Follows the system light/dark appearance and accent colour.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(page: String? = nil, appearance: NSAppearance? = nil) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Utter"
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.appearance = appearance
            let start = page.flatMap { name in Page.allCases.first { $0.rawValue.lowercased() == name.lowercased() } } ?? .home
            window.contentViewController = NSHostingController(rootView: RootView(state: AppState.shared, page: start))
            window.setContentSize(NSSize(width: 820, height: 640))
            window.center()
            self.window = window
        }
        AppState.shared.watchPermissions()
        // Show in the Dock and Cmd-Tab only while the window is open.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    /// Debug aid: capture this app's own window as composited on screen and write a PNG.
    func snapshot(to path: String) {
        guard let window else { return }
        typealias Capture = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return }
        let capture = unsafeBitCast(symbol, to: Capture.self)
        // optionIncludingWindow = 8; boundsIgnoreFraming | bestResolution = 1 | 8
        guard let image = capture(.null, 8, UInt32(window.windowNumber), 9)?.takeRetainedValue() else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
