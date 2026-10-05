import Foundation

// MARK: - Keys

extension SettingKey where Value == Bool {
    static var sleepGuardKeepsDisplayAwake: Self { .bool("sleepGuardKeepsDisplayAwake", default: true) }
    static var sleepGuardShowsRemainingInMenuBar: Self { .bool("sleepGuardShowsRemainingInMenuBar", default: false) }
    static var sleepGuardAllowsIndefinite: Self { .bool("sleepGuardAllowsIndefinite", default: false) }
    static var sleepGuardDisplayAwakeDefaultMigrated: Self { .bool("sleepGuardDisplayAwakeDefaultMigrated", default: false) }
}

extension SettingKey where Value == SleepGuardDuration {
    static var sleepGuardDefaultDuration: Self { .intEnum("sleepGuardDefaultDuration", default: .fifteenMinutes) }
}

// MARK: - Domain logic

extension SpillSettings {
    var availableSleepGuardDurations: [SleepGuardDuration] {
        SleepGuardDuration.availableDurations(allowsIndefinite: sleepGuardAllowsIndefinite)
    }

    /// Earlier builds could persist the old system-only default. Prefer the safer current
    /// default once, then preserve any later explicit opt-out.
    static func loadSleepGuardKeepsDisplayAwake(from defaults: UserDefaults) -> Bool {
        let persisted = defaults.storedObject(for: .sleepGuardKeepsDisplayAwake) as? Bool
        let migrated = defaults.value(for: .sleepGuardDisplayAwakeDefaultMigrated)
        guard !migrated else {
            return persisted ?? true
        }

        defaults.store(true, for: .sleepGuardDisplayAwakeDefaultMigrated)
        guard persisted == false else {
            return persisted ?? true
        }

        defaults.store(true, for: .sleepGuardKeepsDisplayAwake)
        return true
    }

    /// A stored "never" duration is only valid while the user still allows it.
    static func loadSleepGuardDefaultDuration(from defaults: UserDefaults, allowsIndefinite: Bool) -> SleepGuardDuration {
        let persisted = defaults.value(for: .sleepGuardDefaultDuration)
        return persisted.isIndefinite && !allowsIndefinite ? .fifteenMinutes : persisted
    }
}
