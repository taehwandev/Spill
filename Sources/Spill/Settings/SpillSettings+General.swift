import Foundation

// MARK: - Keys

extension SettingKey where Value == SpillAppLanguage {
    static var appLanguage: Self {
        .stringEnum(SpillAppLanguage.defaultsKey, normalize: SpillAppLanguage.normalized(rawValue:))
    }
}

extension SettingKey where Value == SpillAppearanceTheme {
    static var appearanceTheme: Self {
        .stringEnum(SpillAppearanceTheme.defaultsKey, normalize: SpillAppearanceTheme.normalized(rawValue:))
    }
}

extension SettingKey where Value == Bool {
    static var useSpillAnimation: Self { .bool("useSpillAnimation", default: true) }
}

extension SettingKey where Value == Double {
    /// Seconds between status refreshes; never faster than five seconds.
    static var refreshInterval: Self {
        .double("refreshInterval", default: 15) { $0.isFinite ? max($0, 5) : 15 }
    }
}

// MARK: - Reloading from another process

extension SpillSettings {
    /// The dashboard and Settings run in separate processes sharing one defaults suite; these
    /// pull a value another process changed into this instance.
    func reloadAppLanguageFromDefaults() {
        reload(\.appLanguage, from: .appLanguage)
    }

    func reloadAppearanceThemeFromDefaults() {
        reload(\.appearanceTheme, from: .appearanceTheme)
    }

    func reload<Value: Equatable>(
        _ property: ReferenceWritableKeyPath<SpillSettings, Value>,
        from key: SettingKey<Value>
    ) {
        defaults.synchronize()
        let persisted = defaults.value(for: key)
        guard self[keyPath: property] != persisted else {
            return
        }

        self[keyPath: property] = persisted
    }
}
