import Foundation

// MARK: - Keys

extension SettingKey where Value == Set<SpillMenuBarStatusItem> {
    static var enabledMenuBarStatusItems: Self {
        Self(
            "enabledMenuBarStatusItems",
            decode: { SpillMenuBarStatusItem.normalizedEnabled(from: $0 as? [String]) },
            encode: { items in
                SpillMenuBarStatusItem.defaultOrder.filter { items.contains($0) }.map(\.rawValue)
            }
        )
    }
}

extension SettingKey where Value == [SpillMenuBarStatusItem: MenuBarStatusPresentationStyle] {
    static var menuBarMetricPresentationStyles: Self {
        Self(
            "menuBarMetricPresentationStyles",
            decode: {
                SpillSettings.normalizedMenuBarMetricPresentationStyles(
                    from: $0 as? [String: Any],
                    legacyStyle: .text
                )
            },
            encode: { styles in
                Dictionary(uniqueKeysWithValues: SpillMenuBarStatusItem.graphPresentationSupported.map {
                    ($0.rawValue, (styles[$0] ?? .text).rawValue)
                })
            }
        )
    }
}

extension SettingKey where Value == MenuBarStatusPresentationStyle {
    /// One style for every metric, before styles became per-item.
    static var legacyMenuBarStatusPresentationStyle: Self {
        .stringEnum("menuBarStatusPresentationStyle", default: .text)
    }
}

extension SettingKey where Value == MenuBarStatusLayoutStyle {
    static var menuBarStatusLayoutStyle: Self { .stringEnum("menuBarStatusLayoutStyle", default: .inline) }
}

extension SettingKey where Value == MenuBarStatusPrecision {
    static var menuBarStatusPrecision: Self { .intEnum("menuBarStatusPrecision", default: .tenths) }
}

extension SettingKey where Value == MenuBarStatusHighlightThreshold {
    static var menuBarStatusHighlightThreshold: Self {
        .intEnum("menuBarStatusHighlightThreshold", default: .seventy)
    }
}

extension SettingKey where Value == MenuBarTriggerIconStyle {
    static var menuBarTriggerIconStyle: Self {
        .stringEnum("menuBarTriggerIconStyle", normalize: MenuBarTriggerIconStyle.normalized(rawValue:))
    }
}

extension SettingKey where Value == MenuBarTokenDisplayMode {
    static var menuBarTokenDisplayMode: Self { .stringEnum("menuBarTokenDisplayMode", default: .daily) }
}

extension SettingKey where Value == Bool {
    static var menuBarStatusCompactMode: Self { .bool("menuBarStatusCompactMode", default: false) }
    static var menuBarStatusSplitGroups: Self { .bool("menuBarStatusSplitGroups", default: false) }
    static var menuBarStatusTextBold: Self { .bool("menuBarStatusTextBold", default: false) }
}

extension SettingKey where Value == Double {
    static var menuBarStatusFontSize: Self {
        .double("menuBarStatusFontSize", default: 13.5) { $0.isFinite ? $0.clamped(to: 10...15) : 13.5 }
    }
}

// MARK: - Domain logic

extension SpillSettings {
    func isMenuBarStatusItemEnabled(_ item: SpillMenuBarStatusItem) -> Bool {
        enabledMenuBarStatusItems.contains(item)
    }

    func setMenuBarStatusItem(_ item: SpillMenuBarStatusItem, enabled: Bool) {
        guard SpillMenuBarStatusItem.glanceSupported.contains(item) else {
            return
        }

        if enabled {
            enabledMenuBarStatusItems.insert(item)
        } else {
            enabledMenuBarStatusItems.remove(item)
        }
    }

    func menuBarStatusPresentationStyle(
        for item: SpillMenuBarStatusItem
    ) -> MenuBarStatusPresentationStyle {
        menuBarMetricPresentationStyles[item] ?? .text
    }

    func menuBarMetricPresentationMode(
        for item: SpillMenuBarStatusItem
    ) -> MenuBarMetricPresentationMode {
        guard enabledMenuBarStatusItems.contains(item) else {
            return .off
        }

        switch menuBarStatusPresentationStyle(for: item) {
        case .text:
            return .text
        case .chart:
            return .chart
        }
    }

    func setMenuBarMetricPresentationMode(
        _ mode: MenuBarMetricPresentationMode,
        for item: SpillMenuBarStatusItem
    ) {
        guard SpillMenuBarStatusItem.graphPresentationSupported.contains(item) else {
            return
        }

        guard let presentationStyle = mode.presentationStyle else {
            setMenuBarStatusItem(item, enabled: false)
            return
        }

        var updatedStyles = menuBarMetricPresentationStyles
        updatedStyles[item] = presentationStyle
        menuBarMetricPresentationStyles = updatedStyles
        setMenuBarStatusItem(item, enabled: true)
    }

    var hasTextPresentedMenuBarStatusItems: Bool {
        enabledMenuBarStatusItems.contains(.ai)
            || SpillMenuBarStatusItem.graphPresentationSupported.contains {
                enabledMenuBarStatusItems.contains($0)
                    && menuBarStatusPresentationStyle(for: $0) == .text
            }
    }

    var statusModulesRequiredForRefresh: Set<SpillStatusModule> {
        let menuBarModules = enabledMenuBarStatusItems.compactMap(\.systemModule)
        return Set(visiblePanelStatusModules)
            .union(menuBarModules)
            .union(menuBarTriggerIconStyle.requiredStatusModules)
    }

    /// Styles became per-item after one style applied to every metric; the old single style seeds
    /// every item until the per-item dictionary exists, which is then written once.
    static func loadMenuBarMetricPresentationStyles(
        from defaults: UserDefaults
    ) -> [SpillMenuBarStatusItem: MenuBarStatusPresentationStyle] {
        let stored = defaults.storedObject(for: .menuBarMetricPresentationStyles) as? [String: Any]
        let styles = normalizedMenuBarMetricPresentationStyles(
            from: stored,
            legacyStyle: defaults.value(for: .legacyMenuBarStatusPresentationStyle)
        )
        if stored == nil {
            defaults.store(styles, for: .menuBarMetricPresentationStyles)
        }
        return styles
    }

    nonisolated static func normalizedMenuBarMetricPresentationStyles(
        from rawValues: [String: Any]?,
        legacyStyle: MenuBarStatusPresentationStyle
    ) -> [SpillMenuBarStatusItem: MenuBarStatusPresentationStyle] {
        var styles = Dictionary(uniqueKeysWithValues: SpillMenuBarStatusItem.graphPresentationSupported.map {
            ($0, legacyStyle)
        })

        for (rawItem, rawStyle) in rawValues ?? [:] {
            guard let item = SpillMenuBarStatusItem(rawValue: rawItem),
                  SpillMenuBarStatusItem.graphPresentationSupported.contains(item),
                  let rawStyle = rawStyle as? String,
                  let style = MenuBarStatusPresentationStyle(rawValue: rawStyle)
            else {
                continue
            }

            styles[item] = style
        }

        return styles
    }
}
