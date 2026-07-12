import AppKit

enum SpillAppearanceTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let defaultsKey = "appearanceTheme"

    var id: String { rawValue }

    /// `nil` follows the macOS system appearance; otherwise force light/dark.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    private var titleKey: PreferencesTextKey {
        switch self {
        case .system:
            return .appearanceSystem
        case .light:
            return .appearanceLight
        case .dark:
            return .appearanceDark
        }
    }

    func title(appLanguage: SpillAppLanguage = .persisted()) -> String {
        PreferencesL10n.text(titleKey, appLanguage: appLanguage)
    }

    static func normalized(rawValue: String?) -> Self {
        guard let rawValue, let theme = Self(rawValue: rawValue) else {
            return .system
        }
        return theme
    }

    static func persisted(defaults: UserDefaults = .standard) -> Self {
        normalized(rawValue: defaults.string(forKey: defaultsKey))
    }
}
