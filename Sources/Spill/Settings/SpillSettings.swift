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

    @Published private(set) var statusModuleOrder: [SpillStatusModule] {
        didSet { defaults.set(statusModuleOrder.map(\.rawValue), forKey: Keys.statusModuleOrder) }
    }

    @Published private(set) var enabledStatusModules: Set<SpillStatusModule> {
        didSet {
            let orderedEnabledModules = SpillStatusModule.defaultOrder
                .filter { enabledStatusModules.contains($0) }
                .map(\.rawValue)
            defaults.set(orderedEnabledModules, forKey: Keys.enabledStatusModules)
        }
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        iconSpacing = defaults.object(forKey: Keys.iconSpacing) as? Double ?? 8
        showCountBadge = defaults.object(forKey: Keys.showCountBadge) as? Bool ?? true
        useSpillAnimation = defaults.object(forKey: Keys.useSpillAnimation) as? Bool ?? true
        autoRefreshEnabled = defaults.object(forKey: Keys.autoRefreshEnabled) as? Bool ?? true
        refreshInterval = max(defaults.object(forKey: Keys.refreshInterval) as? Double ?? 15, 5)
        let modeRawValue = defaults.string(forKey: Keys.displayMode) ?? SpillDisplayMode.notchCandidates.rawValue
        displayMode = SpillDisplayMode(rawValue: modeRawValue) ?? .notchCandidates
        statusModuleOrder = SpillStatusModule.normalizedOrder(
            from: defaults.stringArray(forKey: Keys.statusModuleOrder)
        )
        enabledStatusModules = SpillStatusModule.normalizedEnabled(
            from: defaults.stringArray(forKey: Keys.enabledStatusModules)
        )
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

    func isStatusModuleEnabled(_ module: SpillStatusModule) -> Bool {
        enabledStatusModules.contains(module)
    }

    func setStatusModule(_ module: SpillStatusModule, enabled: Bool) {
        if enabled {
            enabledStatusModules.insert(module)
        } else {
            enabledStatusModules.remove(module)
        }
    }

    func setStatusModuleOrder(_ modules: [SpillStatusModule]) {
        statusModuleOrder = SpillStatusModule.normalizedOrder(modules)
    }

    func moveStatusModule(_ module: SpillStatusModule, direction: Int) {
        guard direction != 0,
              let index = statusModuleOrder.firstIndex(of: module)
        else {
            return
        }

        let targetIndex = index + direction
        guard statusModuleOrder.indices.contains(targetIndex) else {
            return
        }

        statusModuleOrder.swapAt(index, targetIndex)
    }
}

private enum Keys {
    static let iconSpacing = "iconSpacing"
    static let showCountBadge = "showCountBadge"
    static let useSpillAnimation = "useSpillAnimation"
    static let autoRefreshEnabled = "autoRefreshEnabled"
    static let refreshInterval = "refreshInterval"
    static let displayMode = "displayMode"
    static let statusModuleOrder = "statusModuleOrder"
    static let enabledStatusModules = "enabledStatusModules"
    static let selectedItemKeys = "selectedItemKeys"
    static let hotKeyEnabled = "hotKeyEnabled"
    static let launchAtLogin = "launchAtLogin"
}
