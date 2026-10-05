import Foundation

// MARK: - Keys

extension SettingKey where Value == Bool {
    static var hotKeyEnabled: Self { .bool("hotKeyEnabled", default: true) }
}

extension SettingKey where Value == [WindowActionKind: WindowActionShortcutKey] {
    static var windowActionShortcutKeys: Self {
        Self(
            "windowActionShortcutKeys",
            decode: { SpillSettings.normalizedWindowActionShortcutKeys(from: $0 as? [String]) },
            encode: { SpillSettings.persistedWindowActionShortcutKeys($0) }
        )
    }
}

// MARK: - Domain logic

extension SpillSettings {
    func shortcutKey(for kind: WindowActionKind) -> WindowActionShortcutKey {
        windowActionShortcutKeys[kind] ?? kind.defaultShortcutKey
    }

    func setWindowActionShortcut(_ key: WindowActionShortcutKey, for kind: WindowActionKind) {
        var updated = windowActionShortcutKeys

        if key != .off {
            for otherKind in WindowActionKind.panelOrder
                where otherKind != kind
                && otherKind.shortcutModifier == kind.shortcutModifier
                && updated[otherKind] == key
            {
                updated[otherKind] = .off
            }
        }

        updated[kind] = key
        windowActionShortcutKeys = Self.normalizedWindowActionShortcutKeys(
            from: Self.persistedWindowActionShortcutKeys(updated)
        )
    }

    /// Keeps one key per modifier: a shortcut already claimed by an earlier action is turned off.
    nonisolated static func normalizedWindowActionShortcutKeys(
        from rawValues: [String]?
    ) -> [WindowActionKind: WindowActionShortcutKey] {
        if shouldMigrateLegacyWindowActionDefaults(rawValues) {
            return WindowActionKind.defaultShortcutKeys
        }

        var parsed: [WindowActionKind: WindowActionShortcutKey] = [:]

        rawValues?.forEach { rawValue in
            let parts = rawValue.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let kind = WindowActionKind(rawValue: parts[0]),
                  let key = WindowActionShortcutKey(rawValue: parts[1])
            else {
                return
            }

            parsed[kind] = key
        }

        var normalized: [WindowActionKind: WindowActionShortcutKey] = [:]
        var usedShortcuts = Set<WindowActionShortcutRegistrationKey>()

        for kind in WindowActionKind.panelOrder {
            let key = parsed[kind] ?? kind.defaultShortcutKey
            guard key != .off else {
                normalized[kind] = .off
                continue
            }

            let registrationKey = WindowActionShortcutRegistrationKey(
                modifier: kind.shortcutModifier,
                key: key
            )
            if usedShortcuts.insert(registrationKey).inserted {
                normalized[kind] = key
            } else {
                normalized[kind] = .off
            }
        }

        return normalized
    }

    /// Two earlier builds shipped different default shortcut sets; a list that still equals one of
    /// them was never customized and moves to the current defaults.
    nonisolated private static func shouldMigrateLegacyWindowActionDefaults(_ rawValues: [String]?) -> Bool {
        guard let rawValues else {
            return false
        }

        let originalCommonDefaults = [
            "leftHalf=leftArrow",
            "rightHalf=rightArrow",
            "center=c",
            "maximize=returnKey",
            "topLeft=one",
            "topRight=two",
            "bottomLeft=three",
            "bottomRight=four",
            "nextDisplay=d",
            "restore=r"
        ]
        let previousCommonDefaults = [
            "leftHalf=leftArrow",
            "rightHalf=rightArrow",
            "center=c",
            "maximize=returnKey",
            "topLeft=u",
            "topRight=i",
            "bottomLeft=j",
            "bottomRight=k",
            "previousDisplay=leftArrow",
            "nextDisplay=rightArrow",
            "restore=deleteKey"
        ]

        return rawValues == originalCommonDefaults || rawValues == previousCommonDefaults
    }

    nonisolated static func persistedWindowActionShortcutKeys(
        _ shortcutKeys: [WindowActionKind: WindowActionShortcutKey]
    ) -> [String] {
        WindowActionKind.panelOrder.map { kind in
            "\(kind.rawValue)=\((shortcutKeys[kind] ?? kind.defaultShortcutKey).rawValue)"
        }
    }
}

private struct WindowActionShortcutRegistrationKey: Hashable {
    let modifier: WindowActionShortcutModifier
    let key: WindowActionShortcutKey
}
