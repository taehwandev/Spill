import Foundation
import SwiftUI

enum SpillAppLanguage: String, CaseIterable, Identifiable {
    case automatic
    case english
    case korean
    case japanese

    static let defaultsKey = "appLanguage"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .english:
            return "English"
        case .korean:
            return "한국어"
        case .japanese:
            return "日本語"
        }
    }

    var detail: String {
        switch self {
        case .automatic:
            return "Follow macOS language"
        case .english:
            return "Use English"
        case .korean:
            return "한국어 사용"
        case .japanese:
            return "日本語を使用"
        }
    }

    var languageCode: String? {
        switch self {
        case .automatic:
            return nil
        case .english:
            return "en"
        case .korean:
            return "ko"
        case .japanese:
            return "ja"
        }
    }

    static func normalized(rawValue: String?) -> Self {
        guard let rawValue, let language = Self(rawValue: rawValue) else {
            return .automatic
        }
        return language
    }

    static func persisted(defaults: UserDefaults = .standard) -> Self {
        normalized(rawValue: defaults.string(forKey: defaultsKey))
    }
}

@MainActor
final class SpillSettings: ObservableObject {
    static let shared = SpillSettings()

    @Published var appLanguage: SpillAppLanguage {
        didSet { defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage) }
    }

    @Published var iconSpacing: Double {
        didSet {
            let normalizedValue = Self.normalizedIconSpacing(iconSpacing)
            if iconSpacing != normalizedValue {
                iconSpacing = normalizedValue
            }
            defaults.set(normalizedValue, forKey: Keys.iconSpacing)
        }
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

    @Published var sleepGuardShowsRemainingInMenuBar: Bool {
        didSet {
            defaults.set(sleepGuardShowsRemainingInMenuBar, forKey: Keys.sleepGuardShowsRemainingInMenuBar)
        }
    }

    @Published var sleepGuardDefaultDuration: SleepGuardDuration {
        didSet { defaults.set(sleepGuardDefaultDuration.rawValue, forKey: Keys.sleepGuardDefaultDuration) }
    }

    @Published var sleepGuardAllowsIndefinite: Bool {
        didSet {
            defaults.set(sleepGuardAllowsIndefinite, forKey: Keys.sleepGuardAllowsIndefinite)
            if !sleepGuardAllowsIndefinite, sleepGuardDefaultDuration.isIndefinite {
                sleepGuardDefaultDuration = .fifteenMinutes
            }
        }
    }

    @Published var useSpillAnimation: Bool {
        didSet { defaults.set(useSpillAnimation, forKey: Keys.useSpillAnimation) }
    }

    @Published var autoRefreshEnabled: Bool {
        didSet { defaults.set(autoRefreshEnabled, forKey: Keys.autoRefreshEnabled) }
    }

    @Published var refreshInterval: Double {
        didSet {
            let normalizedValue = Self.normalizedRefreshInterval(refreshInterval)
            if refreshInterval != normalizedValue {
                refreshInterval = normalizedValue
            }
            defaults.set(normalizedValue, forKey: Keys.refreshInterval)
        }
    }

    @Published var displayMode: SpillDisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Keys.displayMode) }
    }

    @Published private(set) var statusModuleOrder: [SpillStatusModule] {
        didSet { defaults.set(statusModuleOrder.map(\.rawValue), forKey: Keys.statusModuleOrder) }
    }

    @Published private(set) var enabledStatusModules: Set<SpillStatusModule> {
        didSet {
            Self.persistEnabledStatusModules(enabledStatusModules, to: defaults)
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

    @Published var showsCPUCoreChart: Bool {
        didSet { defaults.set(showsCPUCoreChart, forKey: Keys.showsCPUCoreChart) }
    }

    @Published var menuBarStatusLayoutStyle: MenuBarStatusLayoutStyle {
        didSet { defaults.set(menuBarStatusLayoutStyle.rawValue, forKey: Keys.menuBarStatusLayoutStyle) }
    }

    @Published var menuBarStatusPrecision: MenuBarStatusPrecision {
        didSet { defaults.set(menuBarStatusPrecision.rawValue, forKey: Keys.menuBarStatusPrecision) }
    }

    @Published var menuBarStatusHighlightThreshold: MenuBarStatusHighlightThreshold {
        didSet {
            defaults.set(menuBarStatusHighlightThreshold.rawValue, forKey: Keys.menuBarStatusHighlightThreshold)
        }
    }

    @Published var menuBarTriggerIconStyle: MenuBarTriggerIconStyle {
        didSet { defaults.set(menuBarTriggerIconStyle.rawValue, forKey: Keys.menuBarTriggerIconStyle) }
    }

    @Published var selectedItemKeys: Set<String> {
        didSet { defaults.set(Array(selectedItemKeys).sorted(), forKey: Keys.selectedItemKeys) }
    }

    @Published private(set) var hiddenItemKeys: Set<String> {
        didSet { defaults.set(Array(hiddenItemKeys).sorted(), forKey: Keys.hiddenItemKeys) }
    }

    @Published var hotKeyEnabled: Bool {
        didSet { defaults.set(hotKeyEnabled, forKey: Keys.hotKeyEnabled) }
    }

    @Published private(set) var windowActionShortcutKeys: [WindowActionKind: WindowActionShortcutKey] {
        didSet {
            defaults.set(
                Self.persistedWindowActionShortcutKeys(windowActionShortcutKeys),
                forKey: Keys.windowActionShortcutKeys
            )
        }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var tokenUsageBridgeEnabled: Bool {
        didSet { defaults.set(tokenUsageBridgeEnabled, forKey: Keys.tokenUsageBridgeEnabled) }
    }

    @Published var tokenMeteringPromptAllowsLocalDisplayNames: Bool {
        didSet { defaults.set(tokenMeteringPromptAllowsLocalDisplayNames, forKey: Keys.tokenMeteringPromptAllowsLocalDisplayNames) }
    }

    @Published var tokenUsageLocalAliases: [String: String] {
        didSet { defaults.set(tokenUsageLocalAliases, forKey: Keys.tokenUsageLocalAliases) }
    }

    @Published var tokenUsageShowAdvancedTools: Bool {
        didSet { defaults.set(tokenUsageShowAdvancedTools, forKey: Keys.tokenUsageShowAdvancedTools) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appLanguage = SpillAppLanguage.normalized(rawValue: defaults.string(forKey: Keys.appLanguage))
        iconSpacing = Self.normalizedIconSpacing(defaults.object(forKey: Keys.iconSpacing) as? Double)
        showCountBadge = defaults.object(forKey: Keys.showCountBadge) as? Bool ?? true
        showPowerFooter = defaults.object(forKey: Keys.showPowerFooter) as? Bool ?? true
        let persistedSleepGuardKeepsDisplayAwake = defaults.object(forKey: Keys.sleepGuardKeepsDisplayAwake) as? Bool
        let migratedSleepGuardDisplayAwakeDefault = defaults.object(
            forKey: Keys.sleepGuardDisplayAwakeDefaultMigrated
        ) as? Bool ?? false
        // Earlier builds could persist the old system-only default. Prefer the
        // safer current default once, then preserve any later explicit opt-out.
        if !migratedSleepGuardDisplayAwakeDefault, persistedSleepGuardKeepsDisplayAwake == false {
            sleepGuardKeepsDisplayAwake = true
            defaults.set(true, forKey: Keys.sleepGuardKeepsDisplayAwake)
        } else {
            sleepGuardKeepsDisplayAwake = persistedSleepGuardKeepsDisplayAwake ?? true
        }
        if !migratedSleepGuardDisplayAwakeDefault {
            defaults.set(true, forKey: Keys.sleepGuardDisplayAwakeDefaultMigrated)
        }
        sleepGuardShowsRemainingInMenuBar = defaults.object(forKey: Keys.sleepGuardShowsRemainingInMenuBar) as? Bool
            ?? false
        let persistedAllowsIndefinite = defaults.object(forKey: Keys.sleepGuardAllowsIndefinite) as? Bool ?? false
        let sleepGuardDurationRawValue = defaults.object(forKey: Keys.sleepGuardDefaultDuration) as? Int
            ?? SleepGuardDuration.fifteenMinutes.rawValue
        let persistedSleepGuardDuration = SleepGuardDuration(rawValue: sleepGuardDurationRawValue) ?? .fifteenMinutes
        sleepGuardDefaultDuration = persistedSleepGuardDuration.isIndefinite && !persistedAllowsIndefinite
            ? .fifteenMinutes
            : persistedSleepGuardDuration
        sleepGuardAllowsIndefinite = persistedAllowsIndefinite
        useSpillAnimation = defaults.object(forKey: Keys.useSpillAnimation) as? Bool ?? true
        autoRefreshEnabled = defaults.object(forKey: Keys.autoRefreshEnabled) as? Bool ?? true
        refreshInterval = Self.normalizedRefreshInterval(defaults.object(forKey: Keys.refreshInterval) as? Double)
        let modeRawValue = defaults.string(forKey: Keys.displayMode) ?? SpillDisplayMode.notchCandidates.rawValue
        displayMode = SpillDisplayMode(rawValue: modeRawValue) ?? .notchCandidates
        statusModuleOrder = SpillStatusModule.normalizedOrder(
            from: defaults.stringArray(forKey: Keys.statusModuleOrder)
        )
        let rawEnabledStatusModules = defaults.stringArray(forKey: Keys.enabledStatusModules)
        var initialEnabledStatusModules = SpillStatusModule.normalizedEnabled(from: rawEnabledStatusModules)
        let shouldMigrateNetworkStatusModule = Self.shouldMigrateNetworkStatusModuleDefault(
            rawValues: rawEnabledStatusModules,
            defaults: defaults
        )
        if shouldMigrateNetworkStatusModule {
            initialEnabledStatusModules.insert(.network)
        }
        enabledStatusModules = initialEnabledStatusModules
        if defaults.object(forKey: Keys.statusModuleNetworkDefaultEnabledMigrated) as? Bool != true {
            defaults.set(true, forKey: Keys.statusModuleNetworkDefaultEnabledMigrated)
            if shouldMigrateNetworkStatusModule {
                Self.persistEnabledStatusModules(initialEnabledStatusModules, to: defaults)
            }
        }
        enabledMenuBarStatusItems = SpillMenuBarStatusItem.normalizedEnabled(
            from: defaults.stringArray(forKey: Keys.enabledMenuBarStatusItems)
        )
        showsCPUCoreChart = defaults.object(forKey: Keys.showsCPUCoreChart) as? Bool ?? false
        let layoutRawValue = defaults.string(forKey: Keys.menuBarStatusLayoutStyle)
            ?? MenuBarStatusLayoutStyle.inline.rawValue
        menuBarStatusLayoutStyle = MenuBarStatusLayoutStyle(rawValue: layoutRawValue) ?? .inline
        let precisionRawValue = defaults.object(forKey: Keys.menuBarStatusPrecision) as? Int
            ?? MenuBarStatusPrecision.tenths.rawValue
        menuBarStatusPrecision = MenuBarStatusPrecision(rawValue: precisionRawValue) ?? .tenths
        let thresholdRawValue = defaults.object(forKey: Keys.menuBarStatusHighlightThreshold) as? Int
            ?? MenuBarStatusHighlightThreshold.seventy.rawValue
        menuBarStatusHighlightThreshold = MenuBarStatusHighlightThreshold(rawValue: thresholdRawValue) ?? .seventy
        menuBarTriggerIconStyle = MenuBarTriggerIconStyle.normalized(
            rawValue: defaults.string(forKey: Keys.menuBarTriggerIconStyle)
        )
        selectedItemKeys = Set(defaults.stringArray(forKey: Keys.selectedItemKeys) ?? [])
        hiddenItemKeys = Set(defaults.stringArray(forKey: Keys.hiddenItemKeys) ?? [])
        hotKeyEnabled = defaults.object(forKey: Keys.hotKeyEnabled) as? Bool ?? true
        windowActionShortcutKeys = Self.normalizedWindowActionShortcutKeys(
            from: defaults.stringArray(forKey: Keys.windowActionShortcutKeys)
        )
        launchAtLogin = LoginItemController.isEnabled
        tokenUsageBridgeEnabled = defaults.object(forKey: Keys.tokenUsageBridgeEnabled) as? Bool ?? false
        tokenMeteringPromptAllowsLocalDisplayNames = defaults.object(forKey: Keys.tokenMeteringPromptAllowsLocalDisplayNames) as? Bool ?? false
        tokenUsageLocalAliases = defaults.dictionary(forKey: Keys.tokenUsageLocalAliases) as? [String: String] ?? [:]
        tokenUsageShowAdvancedTools = defaults.object(forKey: Keys.tokenUsageShowAdvancedTools) as? Bool ?? false
    }

    func selectionState(for item: MenuBarItemSnapshot) -> MenuBarItemSelectionState {
        selectedItemKeys.contains(item.stableKey) ? .selected : .unselected
    }

    func isItemHidden(_ item: MenuBarItemSnapshot) -> Bool {
        hiddenItemKeys.contains(item.stableKey)
    }

    func setItem(_ item: MenuBarItemSnapshot, selected: Bool) {
        if selected {
            hiddenItemKeys.remove(item.stableKey)
            selectedItemKeys.insert(item.stableKey)
        } else {
            selectedItemKeys.remove(item.stableKey)
        }
    }

    func hideItem(_ item: MenuBarItemSnapshot) {
        selectedItemKeys.remove(item.stableKey)
        hiddenItemKeys.insert(item.stableKey)
    }

    func showItem(_ item: MenuBarItemSnapshot) {
        hiddenItemKeys.remove(item.stableKey)
    }

    func clearSelectedItems() {
        selectedItemKeys = []
    }

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
        return Set(visiblePanelStatusModules)
            .union(menuBarModules)
            .union(menuBarTriggerIconStyle.requiredStatusModules)
    }

    var visiblePanelStatusModules: [SpillStatusModule] {
        statusModuleOrder.filter { enabledStatusModules.contains($0) }
    }

    var availableSleepGuardDurations: [SleepGuardDuration] {
        SleepGuardDuration.availableDurations(allowsIndefinite: sleepGuardAllowsIndefinite)
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

    private static func normalizedWindowActionShortcutKeys(
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

    private static func shouldMigrateLegacyWindowActionDefaults(_ rawValues: [String]?) -> Bool {
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

    private static func persistedWindowActionShortcutKeys(
        _ shortcutKeys: [WindowActionKind: WindowActionShortcutKey]
    ) -> [String] {
        WindowActionKind.panelOrder.map { kind in
            "\(kind.rawValue)=\((shortcutKeys[kind] ?? kind.defaultShortcutKey).rawValue)"
        }
    }

    private static func shouldMigrateNetworkStatusModuleDefault(
        rawValues: [String]?,
        defaults: UserDefaults
    ) -> Bool {
        guard defaults.object(forKey: Keys.statusModuleNetworkDefaultEnabledMigrated) as? Bool != true,
              let rawValues
        else {
            return false
        }

        return !rawValues.contains(SpillStatusModule.network.rawValue)
    }

    private static func persistEnabledStatusModules(
        _ modules: Set<SpillStatusModule>,
        to defaults: UserDefaults
    ) {
        let orderedEnabledModules = SpillStatusModule.defaultOrder
            .filter { modules.contains($0) }
            .map(\.rawValue)
        defaults.set(orderedEnabledModules, forKey: Keys.enabledStatusModules)
    }

    private static func normalizedIconSpacing(_ value: Double?) -> Double {
        guard let value, value.isFinite else {
            return 8
        }

        return value.clamped(to: 2...16)
    }

    private static func normalizedRefreshInterval(_ value: Double?) -> Double {
        guard let value, value.isFinite else {
            return 15
        }

        return max(value, 5)
    }
}

private struct WindowActionShortcutRegistrationKey: Hashable {
    let modifier: WindowActionShortcutModifier
    let key: WindowActionShortcutKey
}

private enum Keys {
    static let appLanguage = SpillAppLanguage.defaultsKey
    static let iconSpacing = "iconSpacing"
    static let showCountBadge = "showCountBadge"
    static let showPowerFooter = "showPowerFooter"
    static let sleepGuardKeepsDisplayAwake = "sleepGuardKeepsDisplayAwake"
    static let sleepGuardDisplayAwakeDefaultMigrated = "sleepGuardDisplayAwakeDefaultMigrated"
    static let sleepGuardShowsRemainingInMenuBar = "sleepGuardShowsRemainingInMenuBar"
    static let sleepGuardAllowsIndefinite = "sleepGuardAllowsIndefinite"
    static let sleepGuardDefaultDuration = "sleepGuardDefaultDuration"
    static let useSpillAnimation = "useSpillAnimation"
    static let autoRefreshEnabled = "autoRefreshEnabled"
    static let refreshInterval = "refreshInterval"
    static let displayMode = "displayMode"
    static let statusModuleOrder = "statusModuleOrder"
    static let enabledStatusModules = "enabledStatusModules"
    static let statusModuleNetworkDefaultEnabledMigrated = "statusModuleNetworkDefaultEnabledMigrated"
    static let enabledMenuBarStatusItems = "enabledMenuBarStatusItems"
    static let showsCPUCoreChart = "showsCPUCoreChart"
    static let menuBarStatusLayoutStyle = "menuBarStatusLayoutStyle"
    static let menuBarStatusPrecision = "menuBarStatusPrecision"
    static let menuBarStatusHighlightThreshold = "menuBarStatusHighlightThreshold"
    static let menuBarTriggerIconStyle = "menuBarTriggerIconStyle"
    static let selectedItemKeys = "selectedItemKeys"
    static let hiddenItemKeys = "hiddenItemKeys"
    static let hotKeyEnabled = "hotKeyEnabled"
    static let windowActionShortcutKeys = "windowActionShortcutKeys"
    static let launchAtLogin = "launchAtLogin"
    static let tokenUsageBridgeEnabled = "tokenUsageBridgeEnabled"
    static let tokenMeteringPromptAllowsLocalDisplayNames = "tokenMeteringPromptAllowsLocalDisplayNames"
    static let tokenUsageLocalAliases = "tokenUsageLocalAliases"
    static let tokenUsageShowAdvancedTools = "tokenUsageShowAdvancedTools"
}
