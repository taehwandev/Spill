import Foundation
import SwiftUI

@MainActor
final class SpillSettings: ObservableObject {
    static let shared = SpillSettings(defaults: sharedDefaults())
    static let aiToolVisibilityDidChangeNotification = Notification.Name("dev.spill.Spill.aiToolVisibilityDidChange")

    @Published var appLanguage: SpillAppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            defaults.synchronize()
        }
    }

    @Published var appearanceTheme: SpillAppearanceTheme {
        didSet {
            defaults.set(appearanceTheme.rawValue, forKey: Keys.appearanceTheme)
            defaults.synchronize()
        }
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

    @Published var panelOnboardingPreviewEnabled: Bool {
        didSet { defaults.set(panelOnboardingPreviewEnabled, forKey: Keys.panelOnboardingPreviewEnabled) }
    }

    @Published var tokenUsageDashboardOnboardingPreviewEnabled: Bool {
        didSet {
            defaults.set(
                tokenUsageDashboardOnboardingPreviewEnabled,
                forKey: Keys.tokenUsageDashboardOnboardingPreviewEnabled
            )
        }
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

    @Published private(set) var menuBarMetricPresentationStyles: [
        SpillMenuBarStatusItem: MenuBarStatusPresentationStyle
    ] {
        didSet {
            Self.persistMenuBarMetricPresentationStyles(menuBarMetricPresentationStyles, to: defaults)
        }
    }

    @Published var menuBarStatusLayoutStyle: MenuBarStatusLayoutStyle {
        didSet { defaults.set(menuBarStatusLayoutStyle.rawValue, forKey: Keys.menuBarStatusLayoutStyle) }
    }

    @Published var menuBarStatusCompactMode: Bool {
        didSet { defaults.set(menuBarStatusCompactMode, forKey: Keys.menuBarStatusCompactMode) }
    }

    @Published var menuBarStatusSplitGroups: Bool {
        didSet { defaults.set(menuBarStatusSplitGroups, forKey: Keys.menuBarStatusSplitGroups) }
    }

    @Published var menuBarStatusPrecision: MenuBarStatusPrecision {
        didSet { defaults.set(menuBarStatusPrecision.rawValue, forKey: Keys.menuBarStatusPrecision) }
    }

    @Published var menuBarStatusHighlightThreshold: MenuBarStatusHighlightThreshold {
        didSet {
            defaults.set(menuBarStatusHighlightThreshold.rawValue, forKey: Keys.menuBarStatusHighlightThreshold)
        }
    }

    @Published var menuBarStatusFontSize: Double {
        didSet {
            let normalizedValue = Self.normalizedMenuBarStatusFontSize(menuBarStatusFontSize)
            if menuBarStatusFontSize != normalizedValue {
                menuBarStatusFontSize = normalizedValue
            }
            defaults.set(normalizedValue, forKey: Keys.menuBarStatusFontSize)
        }
    }

    @Published var menuBarStatusTextBold: Bool {
        didSet { defaults.set(menuBarStatusTextBold, forKey: Keys.menuBarStatusTextBold) }
    }

    @Published var menuBarTriggerIconStyle: MenuBarTriggerIconStyle {
        didSet { defaults.set(menuBarTriggerIconStyle.rawValue, forKey: Keys.menuBarTriggerIconStyle) }
    }

    @Published var glanceEnabled: Bool {
        didSet { defaults.set(glanceEnabled, forKey: Keys.glanceEnabled) }
    }

    @Published var glanceDisplayStyle: SpillGlanceDisplayStyle {
        didSet { defaults.set(glanceDisplayStyle.rawValue, forKey: Keys.glanceDisplayStyle) }
    }

    @Published var glanceShowInFullScreen: Bool {
        didSet { defaults.set(glanceShowInFullScreen, forKey: Keys.glanceShowInFullScreen) }
    }

    @Published var glanceReactiveRotationEnabled: Bool {
        didSet {
            defaults.set(
                glanceReactiveRotationEnabled,
                forKey: Keys.glanceReactiveRotationEnabled
            )
        }
    }

    @Published var glanceWorkRotationEnabled: Bool {
        didSet {
            defaults.set(
                glanceWorkRotationEnabled,
                forKey: Keys.glanceWorkRotationEnabled
            )
        }
    }

    @Published private(set) var enabledGlanceModules: Set<SpillGlanceModule> {
        didSet {
            Self.persistEnabledGlanceModules(enabledGlanceModules, to: defaults)
        }
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

    @Published var tokenUsageLocalAliases: [String: String] {
        didSet { defaults.set(tokenUsageLocalAliases, forKey: Keys.tokenUsageLocalAliases) }
    }

    @Published var tokenUsageShowAdvancedTools: Bool {
        didSet { defaults.set(tokenUsageShowAdvancedTools, forKey: Keys.tokenUsageShowAdvancedTools) }
    }

    @Published var tokenUsageInputScope: TokenUsageInputScope {
        didSet {
            defaults.set(tokenUsageInputScope.rawValue, forKey: Keys.tokenUsageInputScope)
            defaults.synchronize()
        }
    }

    @Published var hiddenTokenUsageAITools: Set<TokenUsageAITool> {
        didSet {
            defaults.set(
                hiddenTokenUsageAITools
                    .map(\.rawValue)
                    .sorted(),
                forKey: Keys.hiddenTokenUsageAITools
            )
        }
    }

    @Published var hiddenLocalAIToolKinds: Set<LocalAIToolKind> {
        didSet {
            defaults.set(
                hiddenLocalAIToolKinds
                    .map(\.rawValue)
                    .sorted(),
                forKey: Keys.hiddenLocalAIToolKinds
            )
        }
    }

    @Published var menuBarTokenDisplayMode: MenuBarTokenDisplayMode {
        didSet { defaults.set(menuBarTokenDisplayMode.rawValue, forKey: Keys.menuBarTokenDisplayMode) }
    }

    @Published var privateUsageUploadEnvironment: PrivateUsageUploadEnvironment {
        didSet {
            defaults.set(privateUsageUploadEnvironment.rawValue, forKey: Keys.privateUsageUploadEnvironment)
            privateUsageUploadEnabled = Self.privateUsageUploadEnabled(
                defaults: defaults,
                environment: privateUsageUploadEnvironment
            )
        }
    }

    @Published var privateUsageUploadEnabled: Bool {
        didSet {
            defaults.set(
                privateUsageUploadEnabled,
                forKey: Self.privateUsageUploadEnabledKey(for: privateUsageUploadEnvironment)
            )
        }
    }

    @Published var statusValueBold: Bool {
        didSet { defaults.set(statusValueBold, forKey: Keys.statusValueBold) }
    }

    @Published var statusFontDesign: SpillStatusFontDesign {
        didSet { defaults.set(statusFontDesign.rawValue, forKey: Keys.statusFontDesign) }
    }

    @Published var statusValueFontSize: Double {
        didSet { defaults.set(statusValueFontSize, forKey: Keys.statusValueFontSize) }
    }

    @Published var panelSectionSpacing: Double {
        didSet { defaults.set(panelSectionSpacing, forKey: Keys.panelSectionSpacing) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appLanguage = SpillAppLanguage.normalized(rawValue: defaults.string(forKey: Keys.appLanguage))
        appearanceTheme = SpillAppearanceTheme.normalized(rawValue: defaults.string(forKey: Keys.appearanceTheme))
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
        panelOnboardingPreviewEnabled = defaults.object(forKey: Keys.panelOnboardingPreviewEnabled) as? Bool ?? false
        tokenUsageDashboardOnboardingPreviewEnabled =
            defaults.object(forKey: Keys.tokenUsageDashboardOnboardingPreviewEnabled) as? Bool ?? false
        let presentationRawValue = defaults.string(forKey: Keys.menuBarStatusPresentationStyle)
            ?? MenuBarStatusPresentationStyle.text.rawValue
        let legacyPresentationStyle = MenuBarStatusPresentationStyle(rawValue: presentationRawValue) ?? .text
        let persistedMetricPresentationStyles = defaults.dictionary(
            forKey: Keys.menuBarMetricPresentationStyles
        )
        let initialMetricPresentationStyles = Self.normalizedMenuBarMetricPresentationStyles(
            from: persistedMetricPresentationStyles,
            legacyStyle: legacyPresentationStyle
        )
        menuBarMetricPresentationStyles = initialMetricPresentationStyles
        if persistedMetricPresentationStyles == nil {
            Self.persistMenuBarMetricPresentationStyles(initialMetricPresentationStyles, to: defaults)
        }
        let layoutRawValue = defaults.string(forKey: Keys.menuBarStatusLayoutStyle)
            ?? MenuBarStatusLayoutStyle.inline.rawValue
        menuBarStatusLayoutStyle = MenuBarStatusLayoutStyle(rawValue: layoutRawValue) ?? .inline
        menuBarStatusCompactMode = defaults.object(forKey: Keys.menuBarStatusCompactMode) as? Bool ?? false
        menuBarStatusSplitGroups = defaults.object(forKey: Keys.menuBarStatusSplitGroups) as? Bool ?? false
        let precisionRawValue = defaults.object(forKey: Keys.menuBarStatusPrecision) as? Int
            ?? MenuBarStatusPrecision.tenths.rawValue
        menuBarStatusPrecision = MenuBarStatusPrecision(rawValue: precisionRawValue) ?? .tenths
        let thresholdRawValue = defaults.object(forKey: Keys.menuBarStatusHighlightThreshold) as? Int
            ?? MenuBarStatusHighlightThreshold.seventy.rawValue
        menuBarStatusHighlightThreshold = MenuBarStatusHighlightThreshold(rawValue: thresholdRawValue) ?? .seventy
        menuBarStatusFontSize = Self.normalizedMenuBarStatusFontSize(
            defaults.object(forKey: Keys.menuBarStatusFontSize) as? Double
        )
        menuBarStatusTextBold = defaults.object(forKey: Keys.menuBarStatusTextBold) as? Bool ?? false
        menuBarTriggerIconStyle = MenuBarTriggerIconStyle.normalized(
            rawValue: defaults.string(forKey: Keys.menuBarTriggerIconStyle)
        )
        glanceEnabled = defaults.object(forKey: Keys.glanceEnabled) as? Bool ?? true
        glanceDisplayStyle = SpillGlanceDisplayStyle.normalized(
            rawValue: defaults.string(forKey: Keys.glanceDisplayStyle)
        )
        glanceShowInFullScreen = defaults.object(forKey: Keys.glanceShowInFullScreen) as? Bool ?? false
        glanceReactiveRotationEnabled =
            defaults.object(forKey: Keys.glanceReactiveRotationEnabled) as? Bool ?? true
        glanceWorkRotationEnabled =
            defaults.object(forKey: Keys.glanceWorkRotationEnabled) as? Bool ?? true
        let rawEnabledGlanceModules = defaults.stringArray(forKey: Keys.enabledGlanceModules)
        let initialEnabledGlanceModules = SpillGlanceModule.normalizedEnabled(from: rawEnabledGlanceModules)
        enabledGlanceModules = initialEnabledGlanceModules
        if rawEnabledGlanceModules != nil {
            Self.persistEnabledGlanceModules(initialEnabledGlanceModules, to: defaults)
        }
        selectedItemKeys = Set(defaults.stringArray(forKey: Keys.selectedItemKeys) ?? [])
        hiddenItemKeys = Set(defaults.stringArray(forKey: Keys.hiddenItemKeys) ?? [])
        hotKeyEnabled = defaults.object(forKey: Keys.hotKeyEnabled) as? Bool ?? true
        windowActionShortcutKeys = Self.normalizedWindowActionShortcutKeys(
            from: defaults.stringArray(forKey: Keys.windowActionShortcutKeys)
        )
        launchAtLogin = LoginItemController.isEnabled
        tokenUsageBridgeEnabled = defaults.object(forKey: Keys.tokenUsageBridgeEnabled) as? Bool ?? false
        tokenUsageLocalAliases = defaults.dictionary(forKey: Keys.tokenUsageLocalAliases) as? [String: String] ?? [:]
        tokenUsageShowAdvancedTools = defaults.object(forKey: Keys.tokenUsageShowAdvancedTools) as? Bool ?? false
        tokenUsageInputScope = TokenUsageInputScope.normalized(
            rawValue: defaults.string(forKey: Keys.tokenUsageInputScope)
        )
        let persistedHiddenTokenUsageAITools = Self.normalizedTokenUsageAITools(
            from: defaults.stringArray(forKey: Keys.hiddenTokenUsageAITools)
        )
        let persistedHiddenLocalAIToolKinds = Self.normalizedLocalAIToolKinds(
            from: defaults.stringArray(forKey: Keys.hiddenLocalAIToolKinds)
        )
        hiddenTokenUsageAITools = persistedHiddenTokenUsageAITools.union(
            persistedHiddenLocalAIToolKinds.compactMap(\.tokenUsageDashboardTool)
        )
        hiddenLocalAIToolKinds = persistedHiddenLocalAIToolKinds.union(
            persistedHiddenTokenUsageAITools.compactMap(\.localAIToolKind)
        )
        let menuBarTokenDisplayModeRaw = defaults.string(forKey: Keys.menuBarTokenDisplayMode) ?? MenuBarTokenDisplayMode.daily.rawValue
        menuBarTokenDisplayMode = MenuBarTokenDisplayMode(rawValue: menuBarTokenDisplayModeRaw) ?? .daily
        let privateUsageEnvironment = PrivateUsageUploadEnvironment.resolvedFromConfiguration()
            ?? defaults.string(forKey: Keys.privateUsageUploadEnvironment)
                .flatMap(PrivateUsageUploadEnvironment.init(rawValue:))
            ?? .defaultValue
        privateUsageUploadEnvironment = privateUsageEnvironment
        privateUsageUploadEnabled = Self.privateUsageUploadEnabled(
            defaults: defaults,
            environment: privateUsageEnvironment
        )
        statusValueBold = defaults.object(forKey: Keys.statusValueBold) as? Bool ?? true
        let fontDesignRaw = defaults.string(forKey: Keys.statusFontDesign) ?? SpillStatusFontDesign.rounded.rawValue
        statusFontDesign = SpillStatusFontDesign(rawValue: fontDesignRaw) ?? .rounded
        statusValueFontSize = defaults.object(forKey: Keys.statusValueFontSize) as? Double ?? 16
        panelSectionSpacing = defaults.object(forKey: Keys.panelSectionSpacing) as? Double ?? 14
    }

}

extension SpillSettings {
    static func sharedDefaults(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UserDefaults {
        guard let suiteName = sharedDefaultsSuiteName(
            bundleIdentifier: bundleIdentifier,
            arguments: arguments,
            environment: environment
        ) else {
            return .standard
        }

        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func sharedDefaultsSuiteName(
        bundleIdentifier: String?,
        arguments: [String],
        environment: [String: String]
    ) -> String? {
        let isDashboardProcess = environment[TokenMeteringDashboardProcess.standaloneEnvironmentKey] == "1"
            || arguments.contains(TokenMeteringDashboardProcess.standaloneArgument)
            || TokenMeteringDashboardProcess.isDashboardBundleIdentifier(bundleIdentifier)
        guard isDashboardProcess else {
            return nil
        }

        if let mainBundleIdentifier = environment[TokenMeteringDashboardProcess.mainBundleIdentifierEnvironmentKey],
           !mainBundleIdentifier.isEmpty
        {
            return mainBundleIdentifier
        }

        guard let bundleIdentifier,
              TokenMeteringDashboardProcess.isDashboardBundleIdentifier(bundleIdentifier)
        else {
            return nil
        }

        return String(bundleIdentifier.dropLast(TokenMeteringDashboardProcess.helperBundleIdentifierSuffix.count))
    }
}

extension SpillSettings {
    func reloadAppLanguageFromDefaults() {
        defaults.synchronize()
        let persistedLanguage = SpillAppLanguage.normalized(rawValue: defaults.string(forKey: Keys.appLanguage))
        guard appLanguage != persistedLanguage else {
            return
        }

        appLanguage = persistedLanguage
    }

    func reloadAppearanceThemeFromDefaults() {
        defaults.synchronize()
        let persistedTheme = SpillAppearanceTheme.normalized(rawValue: defaults.string(forKey: Keys.appearanceTheme))
        guard appearanceTheme != persistedTheme else {
            return
        }

        appearanceTheme = persistedTheme
    }

    func reloadTokenUsageDashboardOnboardingPreviewFromDefaults() {
        defaults.synchronize()
        let persistedValue = defaults.object(forKey: Keys.tokenUsageDashboardOnboardingPreviewEnabled) as? Bool ?? false
        guard tokenUsageDashboardOnboardingPreviewEnabled != persistedValue else {
            return
        }

        tokenUsageDashboardOnboardingPreviewEnabled = persistedValue
    }

    func reloadTokenUsageInputScopeFromDefaults() {
        defaults.synchronize()
        let persistedScope = TokenUsageInputScope.normalized(
            rawValue: defaults.string(forKey: Keys.tokenUsageInputScope)
        )
        guard tokenUsageInputScope != persistedScope else {
            return
        }

        tokenUsageInputScope = persistedScope
    }
}

extension SpillSettings {
    var visibleGlanceModules: [SpillGlanceModule] {
        guard glanceEnabled else {
            return []
        }

        return SpillGlanceModule.defaultOrder.filter {
            SpillGlanceModule.fixedModules.contains($0)
                || enabledGlanceModules.contains($0)
        }
    }

    func isGlanceModuleEnabled(_ module: SpillGlanceModule) -> Bool {
        SpillGlanceModule.fixedModules.contains(module)
            || enabledGlanceModules.contains(module)
    }

    func setGlanceModule(_ module: SpillGlanceModule, enabled: Bool) {
        guard SpillGlanceModule.configurableToolModules.contains(module) else {
            return
        }

        if enabled {
            enabledGlanceModules.insert(module)
        } else {
            enabledGlanceModules.remove(module)
        }
    }

    private static func persistEnabledGlanceModules(
        _ modules: Set<SpillGlanceModule>,
        to defaults: UserDefaults
    ) {
        let orderedEnabledModules = SpillGlanceModule.configurableToolModules
            .filter { modules.contains($0) }
            .map(\.rawValue)
        defaults.set(orderedEnabledModules, forKey: Keys.enabledGlanceModules)
    }
}

extension SpillSettings {
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
}

extension SpillSettings {
    func setTokenUsageAITool(_ tool: TokenUsageAITool, isVisible: Bool) {
        guard tool.isDashboardTool else {
            return
        }

        if isVisible {
            hiddenTokenUsageAITools.remove(tool)
        } else {
            hiddenTokenUsageAITools.insert(tool)
        }
        if let kind = tool.localAIToolKind {
            setLocalAITool(kind, isVisible: isVisible, postsVisibilityChange: false)
        }
        postAIToolVisibilityDidChange()
    }

    func isTokenUsageAIToolVisible(_ tool: TokenUsageAITool) -> Bool {
        !hiddenTokenUsageAITools.contains(tool)
    }

    func setLocalAITool(_ kind: LocalAIToolKind, isVisible: Bool) {
        setLocalAITool(kind, isVisible: isVisible, postsVisibilityChange: true)
    }

    func isLocalAIToolVisible(_ kind: LocalAIToolKind) -> Bool {
        !hiddenLocalAIToolKinds.contains(kind)
    }

    func reloadAIToolVisibilityFromDefaults() {
        defaults.synchronize()
        let persistedHiddenTokenUsageAITools = Self.normalizedTokenUsageAITools(
            from: defaults.stringArray(forKey: Keys.hiddenTokenUsageAITools)
        )
        let persistedHiddenLocalAIToolKinds = Self.normalizedLocalAIToolKinds(
            from: defaults.stringArray(forKey: Keys.hiddenLocalAIToolKinds)
        )
        let nextHiddenTokenUsageAITools = persistedHiddenTokenUsageAITools.union(
            persistedHiddenLocalAIToolKinds.compactMap(\.tokenUsageDashboardTool)
        )
        let nextHiddenLocalAIToolKinds = persistedHiddenLocalAIToolKinds.union(
            persistedHiddenTokenUsageAITools.compactMap(\.localAIToolKind)
        )

        if hiddenTokenUsageAITools != nextHiddenTokenUsageAITools {
            hiddenTokenUsageAITools = nextHiddenTokenUsageAITools
        }
        if hiddenLocalAIToolKinds != nextHiddenLocalAIToolKinds {
            hiddenLocalAIToolKinds = nextHiddenLocalAIToolKinds
        }
    }

    private func setLocalAITool(_ kind: LocalAIToolKind, isVisible: Bool, postsVisibilityChange: Bool) {
        if isVisible {
            hiddenLocalAIToolKinds.remove(kind)
        } else {
            hiddenLocalAIToolKinds.insert(kind)
        }
        if let tool = kind.tokenUsageDashboardTool {
            if isVisible {
                hiddenTokenUsageAITools.remove(tool)
            } else {
                hiddenTokenUsageAITools.insert(tool)
            }
        }
        if postsVisibilityChange {
            postAIToolVisibilityDidChange()
        }
    }

    private func postAIToolVisibilityDidChange() {
        DistributedNotificationCenter.default().post(
            name: Self.aiToolVisibilityDidChangeNotification,
            object: nil
        )
    }
}

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
        statusModuleOrder.filter { enabledStatusModules.contains($0) }
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
}

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

    private static func normalizedMenuBarMetricPresentationStyles(
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

    private static func persistMenuBarMetricPresentationStyles(
        _ styles: [SpillMenuBarStatusItem: MenuBarStatusPresentationStyle],
        to defaults: UserDefaults
    ) {
        let rawStyles = Dictionary(uniqueKeysWithValues: SpillMenuBarStatusItem.graphPresentationSupported.map {
            ($0.rawValue, (styles[$0] ?? .text).rawValue)
        })
        defaults.set(rawStyles, forKey: Keys.menuBarMetricPresentationStyles)
    }
}

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
}

extension SpillSettings {
    var availableSleepGuardDurations: [SleepGuardDuration] {
        SleepGuardDuration.availableDurations(allowsIndefinite: sleepGuardAllowsIndefinite)
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

    private static func normalizedMenuBarStatusFontSize(_ value: Double?) -> Double {
        guard let value, value.isFinite else {
            return 13.5
        }

        return value.clamped(to: 10...15)
    }

    private static func normalizedTokenUsageAITools(from rawValues: [String]?) -> Set<TokenUsageAITool> {
        Set(
            rawValues?
                .compactMap(TokenUsageAITool.init(rawValue:))
                .filter(\.isDashboardTool) ?? []
        )
    }

    private static func normalizedLocalAIToolKinds(from rawValues: [String]?) -> Set<LocalAIToolKind> {
        Set(rawValues?.compactMap(LocalAIToolKind.init(rawValue:)) ?? [])
    }

    private static func privateUsageUploadEnabled(
        defaults: UserDefaults,
        environment: PrivateUsageUploadEnvironment
    ) -> Bool {
        defaults.object(forKey: privateUsageUploadEnabledKey(for: environment)) as? Bool ?? false
    }

    private static func privateUsageUploadEnabledKey(for environment: PrivateUsageUploadEnvironment) -> String {
        "\(Keys.privateUsageUploadEnabled).\(environment.rawValue)"
    }
}

private struct WindowActionShortcutRegistrationKey: Hashable {
    let modifier: WindowActionShortcutModifier
    let key: WindowActionShortcutKey
}

private enum Keys {
    static let appLanguage = SpillAppLanguage.defaultsKey
    static let appearanceTheme = SpillAppearanceTheme.defaultsKey
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
    static let panelOnboardingPreviewEnabled = "panelOnboardingPreviewEnabled"
    static let tokenUsageDashboardOnboardingPreviewEnabled = "tokenUsageDashboardOnboardingPreviewEnabled"
    static let menuBarStatusPresentationStyle = "menuBarStatusPresentationStyle"
    static let menuBarMetricPresentationStyles = "menuBarMetricPresentationStyles"
    static let menuBarStatusLayoutStyle = "menuBarStatusLayoutStyle"
    static let menuBarStatusCompactMode = "menuBarStatusCompactMode"
    static let menuBarStatusSplitGroups = "menuBarStatusSplitGroups"
    static let menuBarStatusPrecision = "menuBarStatusPrecision"
    static let menuBarStatusHighlightThreshold = "menuBarStatusHighlightThreshold"
    static let menuBarStatusFontSize = "menuBarStatusFontSize"
    static let menuBarStatusTextBold = "menuBarStatusTextBold"
    static let menuBarTriggerIconStyle = "menuBarTriggerIconStyle"
    static let glanceEnabled = "glanceEnabled"
    static let glanceDisplayStyle = "glanceDisplayStyle"
    static let glanceShowInFullScreen = "glanceShowInFullScreen"
    static let glanceReactiveRotationEnabled = "glanceReactiveRotationEnabled"
    static let glanceWorkRotationEnabled = "glanceWorkRotationEnabled"
    static let enabledGlanceModules = "enabledGlanceModules"
    static let selectedItemKeys = "selectedItemKeys"
    static let hiddenItemKeys = "hiddenItemKeys"
    static let hotKeyEnabled = "hotKeyEnabled"
    static let windowActionShortcutKeys = "windowActionShortcutKeys"
    static let launchAtLogin = "launchAtLogin"
    static let tokenUsageBridgeEnabled = "tokenUsageBridgeEnabled"
    static let tokenUsageLocalAliases = "tokenUsageLocalAliases"
    static let tokenUsageShowAdvancedTools = "tokenUsageShowAdvancedTools"
    static let tokenUsageInputScope = "tokenUsageInputScope"
    static let hiddenTokenUsageAITools = "hiddenTokenUsageAITools"
    static let hiddenLocalAIToolKinds = "hiddenLocalAIToolKinds"
    static let menuBarTokenDisplayMode = "menuBarTokenDisplayMode"
    static let privateUsageUploadEnvironment = "privateUsageUploadEnvironment"
    static let privateUsageUploadEnabled = "privateUsageUploadEnabled"
    static let statusValueBold = "statusValueBold"
    static let statusFontDesign = "statusFontDesign"
    static let statusValueFontSize = "statusValueFontSize"
    static let panelSectionSpacing = "panelSectionSpacing"
}
