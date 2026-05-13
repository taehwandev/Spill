import Foundation
import SwiftUI

@MainActor
final class SpillSettings: ObservableObject {
    static let shared = SpillSettings()

    @Published var iconSpacing: Double {
        didSet { defaults.set(iconSpacing, forKey: Keys.iconSpacing) }
    }

    @Published var showCountBadge: Bool {
        didSet { defaults.set(showCountBadge, forKey: Keys.showCountBadge) }
    }

    @Published var useSpillAnimation: Bool {
        didSet { defaults.set(useSpillAnimation, forKey: Keys.useSpillAnimation) }
    }

    @Published var autoRefreshEnabled: Bool {
        didSet { defaults.set(autoRefreshEnabled, forKey: Keys.autoRefreshEnabled) }
    }

    @Published var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    @Published var displayMode: SpillDisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Keys.displayMode) }
    }

    @Published var selectedItemKeys: Set<String> {
        didSet { defaults.set(Array(selectedItemKeys).sorted(), forKey: Keys.selectedItemKeys) }
    }

    @Published var hotKeyEnabled: Bool {
        didSet { defaults.set(hotKeyEnabled, forKey: Keys.hotKeyEnabled) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        iconSpacing = defaults.object(forKey: Keys.iconSpacing) as? Double ?? 8
        showCountBadge = defaults.object(forKey: Keys.showCountBadge) as? Bool ?? true
        useSpillAnimation = defaults.object(forKey: Keys.useSpillAnimation) as? Bool ?? true
        autoRefreshEnabled = defaults.object(forKey: Keys.autoRefreshEnabled) as? Bool ?? true
        refreshInterval = max(defaults.object(forKey: Keys.refreshInterval) as? Double ?? 15, 5)
        let modeRawValue = defaults.string(forKey: Keys.displayMode) ?? SpillDisplayMode.notchCandidates.rawValue
        displayMode = SpillDisplayMode(rawValue: modeRawValue) ?? .notchCandidates
        selectedItemKeys = Set(defaults.stringArray(forKey: Keys.selectedItemKeys) ?? [])
        hotKeyEnabled = defaults.object(forKey: Keys.hotKeyEnabled) as? Bool ?? true
        launchAtLogin = LoginItemController.isEnabled
    }

    func selectionState(for item: MenuBarItemSnapshot) -> MenuBarItemSelectionState {
        selectedItemKeys.contains(item.stableKey) ? .selected : .unselected
    }

    func setItem(_ item: MenuBarItemSnapshot, selected: Bool) {
        if selected {
            selectedItemKeys.insert(item.stableKey)
        } else {
            selectedItemKeys.remove(item.stableKey)
        }
    }

    func clearSelectedItems() {
        selectedItemKeys = []
    }
}

private enum Keys {
    static let iconSpacing = "iconSpacing"
    static let showCountBadge = "showCountBadge"
    static let useSpillAnimation = "useSpillAnimation"
    static let autoRefreshEnabled = "autoRefreshEnabled"
    static let refreshInterval = "refreshInterval"
    static let displayMode = "displayMode"
    static let selectedItemKeys = "selectedItemKeys"
    static let hotKeyEnabled = "hotKeyEnabled"
    static let launchAtLogin = "launchAtLogin"
}
