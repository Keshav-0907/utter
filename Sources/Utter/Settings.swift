import Foundation

enum Settings {
    private static let defaults = UserDefaults.standard

    static var engineID: String {
        get { defaults.string(forKey: "engineID") ?? EngineRegistry.all[0].id }
        set { defaults.set(newValue, forKey: "engineID") }
    }

    static var hotkey: HotkeyChoice {
        get { HotkeyChoice(rawValue: defaults.string(forKey: "hotkey") ?? "") ?? .rightOption }
        set { defaults.set(newValue.rawValue, forKey: "hotkey") }
    }

    static var removeFillers: Bool {
        get { defaults.object(forKey: "removeFillers") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "removeFillers") }
    }

    /// Show the running transcript inside the on-screen pill while speaking.
    static var showLiveText: Bool {
        get { defaults.bool(forKey: "showLiveText") }
        set { defaults.set(newValue, forKey: "showLiveText") }
    }

    static var saveHistory: Bool {
        get { defaults.object(forKey: "saveHistory") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "saveHistory") }
    }

    /// Double-tap the hotkey to keep listening without holding it.
    static var doubleTapLock: Bool {
        get { defaults.object(forKey: "doubleTapLock") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "doubleTapLock") }
    }

    static var cleanupEnabled: Bool {
        get { defaults.bool(forKey: "cleanupEnabled") }
        set { defaults.set(newValue, forKey: "cleanupEnabled") }
    }

    /// "apple", a downloadable model id, or "" when none is chosen.
    static var cleanupChoice: String {
        get { defaults.string(forKey: "cleanupChoice") ?? "" }
        set { defaults.set(newValue, forKey: "cleanupChoice") }
    }
}
