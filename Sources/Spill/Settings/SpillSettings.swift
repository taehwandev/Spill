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

    @Published var showPowerFooter: Bool {
        didSet { defaults.set(showPowerFooter, forKey: Keys.showPowerFooter) }
    }

    @Published var sleepGuardKeepsDisplayAwake: Bool {
        didSet { defaults.set(sleepGuardKeepsDisplayAwake, forKey: Keys.sleepGuardKeepsDisplayAwake) }
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

    @Published private(set) var enabledMenuBarStatusItems: Set<SpillMenuBarStatusItem> {
        didSet {
            let orderedEnabledItems = SpillMenuBarStatusItem.defaultOrder
                .filter { enabledMenuBarStatusItems.contains($0) }
                .map(\.rawValue)
            defaults.set(orderedEnabledItems, forKey: Keys.enabledMenuBarStatusItems)
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
        showPowerFooter = defaults.object(forKey: Keys.showPowerFooter) as? Bool ?? true
        sleepGuardKeepsDisplayAwake = defaults.object(forKey: Keys.sleepGuardKeepsDisplayAwake) as? Bool ?? false
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
        enabledMenuBarStatusItems = SpillMenuBarStatusItem.normalizedEnabled(
            from: defaults.stringArray(forKey: Keys.enabledMenuBarStatusItems)
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

    var statusModulesRequiredForRefresh: Set<SpillStatusModule> {
        let menuBarModules = enabledMenuBarStatusItems.compactMap(\.systemModule)
        return enabledStatusModules.union(menuBarModules)
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
    static let showPowerFooter = "showPowerFooter"
    static let sleepGuardKeepsDisplayAwake = "sleepGuardKeepsDisplayAwake"
    static let useSpillAnimation = "useSpillAnimation"
    static let autoRefreshEnabled = "autoRefreshEnabled"
    static let refreshInterval = "refreshInterval"
    static let displayMode = "displayMode"
    static let statusModuleOrder = "statusModuleOrder"
    static let enabledStatusModules = "enabledStatusModules"
    static let enabledMenuBarStatusItems = "enabledMenuBarStatusItems"
    static let selectedItemKeys = "selectedItemKeys"
    static let hotKeyEnabled = "hotKeyEnabled"
    static let launchAtLogin = "launchAtLogin"
}
