import Foundation

// MARK: - Keys

extension SettingKey where Value == Set<SpillStatusModule> {
    static var enabledStatusModules: Self {
        Self(
            "enabledStatusModules",
            decode: { SpillStatusModule.normalizedEnabled(from: $0 as? [String]) },
            encode: { modules in
                SpillStatusModule.defaultOrder.filter { modules.contains($0) }.map(\.rawValue)
            }
        )
    }
}

extension SettingKey where Value == Bool {
    static var panelStatusValueBold: Self { .bool("statusValueBold", default: true) }
    static var statusModuleNetworkDefaultEnabledMigrated: Self {
        .bool("statusModuleNetworkDefaultEnabledMigrated", default: false)
    }
    static var statusModuleGPUDefaultEnabledMigrated: Self {
        .bool("statusModuleGPUDefaultEnabledMigrated", default: false)
    }
}

extension SettingKey where Value == SpillStatusFontDesign {
    static var panelStatusFontDesign: Self { .stringEnum("statusFontDesign", default: .rounded) }
}

extension SettingKey where Value == Double {
    static var panelStatusValueFontSize: Self { .double("statusValueFontSize", default: 16) }
    static var panelSectionSpacing: Self { .double("panelSectionSpacing", default: 14) }
}

// MARK: - Domain logic

extension SpillSettings {
    func isStatusModuleEnabled(_ module: SpillStatusModule) -> Bool {
        enabledStatusModules.contains(module)
    }

    func setStatusModule(_ module: SpillStatusModule, enabled: Bool) {
        guard SpillStatusModule.defaultOrder.contains(module) else {
            return
        }

        if enabled {
            enabledStatusModules.insert(module)
        } else {
            enabledStatusModules.remove(module)
        }
    }

    var visiblePanelStatusModules: [SpillStatusModule] {
        SpillStatusModule.defaultOrder.filter { enabledStatusModules.contains($0) }
    }

    /// Network and GPU became default-on after earlier builds had stored a list without them.
    /// Each is added back once, the first time a stored list lacking it is seen.
    static func loadEnabledStatusModules(from defaults: UserDefaults) -> Set<SpillStatusModule> {
        let stored = defaults.storedObject(for: .enabledStatusModules) as? [String]
        var modules = defaults.value(for: .enabledStatusModules)
        var persistsMigration = false

        for (module, migratedKey) in [
            (SpillStatusModule.network, SettingKey<Bool>.statusModuleNetworkDefaultEnabledMigrated),
            (SpillStatusModule.gpu, SettingKey<Bool>.statusModuleGPUDefaultEnabledMigrated)
        ] {
            guard !defaults.value(for: migratedKey) else {
                continue
            }

            if let stored, !stored.contains(module.rawValue) {
                modules.insert(module)
                persistsMigration = true
            }
            defaults.store(true, for: migratedKey)
        }
        if persistsMigration {
            defaults.store(modules, for: .enabledStatusModules)
        }
        return modules
    }
}
