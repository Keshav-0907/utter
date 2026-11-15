import AppKit
import Combine

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let state = AppState.shared
    private let mainWindow = MainWindow()
    private var statusItem: NSStatusItem!
    private var dictation: DictationController!
    private var hotkey: HotkeyMonitor!
    private var observers: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        // Debug: `Utter --snapshot out.png [page] [--dark]` renders the window to a file and exits.
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count {
            let page = index + 2 < arguments.count ? arguments[index + 2] : nil
            let dark = arguments.contains("--dark")
            mainWindow.show(page: page, appearance: NSAppearance(named: dark ? .darkAqua : .aqua))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [mainWindow] in
                mainWindow.snapshot(to: arguments[index + 1])
                exit(0)
            }
            return
        }


        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "UtterStatusItem"
        statusItem.isVisible = true
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateStatusIcon(recording: false)

        dictation = DictationController(engine: EngineRegistry.engine(id: state.engineID))

        hotkey = HotkeyMonitor(choice: state.hotkey)
        hotkey.onDown = { [weak self] in self?.dictation.hotkeyDown() }
        hotkey.onUp = { [weak self] in self?.dictation.hotkeyUp() }
        hotkey.onCancel = { [weak self] in self?.dictation.cancel() }
        hotkey.onChord = { [weak self] in self?.dictation.interruptedByShortcut() }

        state.onHotkeyChange = { [weak self] in self?.hotkey.choice = $0 }
        state.onEngineChange = { [weak self] id in
            guard let self else { return }
            self.dictation.engine = EngineRegistry.engine(id: id)
            self.dictation.prepareEngine()
        }
        state.onTrusted = { [weak self] in self?.hotkey.start() }
        state.$isRecording
            .removeDuplicates()
            .sink { [weak self] in self?.updateStatusIcon(recording: $0) }
            .store(in: &observers)

        if state.axTrusted { hotkey.start() }
        if state.micStatus == .notDetermined { state.requestMicrophone() }
        state.watchPermissions()
        dictation.prepareEngine()
        CleanupManager.shared.prepare()

        // Opened by hand: show the window. Started at login with everything set up: stay in the menu bar.
        let launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAtLogin || !state.permissionsOK { mainWindow.show() }
    }

    /// Opening the app again (Spotlight, Finder, Dock) brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow.show()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func updateStatusIcon(recording: Bool) {
        guard let button = statusItem.button else { return }
        button.image = Self.statusGlyph
        button.contentTintColor = recording ? .systemRed : nil
        button.toolTip = "Utter — hold \(state.hotkey.title) to dictate"
    }

    /// Five voice bars, matching the app icon.
    private static let statusGlyph: NSImage = {
        let heights: [CGFloat] = [6, 11, 16, 9, 5]
        let width: CGFloat = 2, gap: CGFloat = 1.5
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let total = CGFloat(heights.count) * width + CGFloat(heights.count - 1) * gap
            var x = (rect.width - total) / 2
            NSColor.black.setFill()
            for height in heights {
                let bar = NSRect(x: x, y: (rect.height - height) / 2, width: width, height: height)
                NSBezierPath(roundedRect: bar, xRadius: width / 2, yRadius: width / 2).fill()
                x += width + gap
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Utter"
        return image
    }()

    // MARK: Menu bar menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        state.refreshPermissions()

        let headline = state.isLocked ? "Listening — tap \(state.hotkey.title) to finish" : state.permissionsOK ? "Hold \(state.hotkey.title) to dictate" : "Setup needed — open Utter"
        menu.addItem(disabled(headline))
        if !state.engineReady { menu.addItem(disabled(state.engineStatus)) }
        menu.addItem(.separator())

        menu.addItem(item("Open Utter…", #selector(showWindow)))
        let copy = item("Copy Last Dictation", #selector(copyLast))
        copy.isEnabled = !state.history.isEmpty
        menu.addItem(copy)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Utter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func showWindow() { mainWindow.show() }

    @objc private func copyLast() {
        if let last = state.history.first { state.copy(last.text) }
    }

    // MARK: Main menu (needed for Cmd-V/C/X/A/W/Q inside our own window)

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Hide Utter", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Utter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        main.addItem(appItem)

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = edit
        main.addItem(editItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        let windowItem = NSMenuItem()
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        return main
    }
}
