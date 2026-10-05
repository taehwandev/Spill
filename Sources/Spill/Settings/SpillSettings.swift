import Foundation
import SwiftUI

/// App-wide preferences, persisted in `UserDefaults`.
///
/// Every setting has the same shape: a `@Published` property whose `didSet` persists through its
/// typed `SettingKey`, loaded once in `init` through that same key. The properties are grouped by
/// domain below; each domain's keys, normalization, migrations and logic live in its own
/// `SpillSettings+<Domain>.swift`, and the stored keys themselves never change.
@MainActor
final class SpillSettings: ObservableObject {
    static let shared = SpillSettings(defaults: sharedDefaults())
    static let aiToolVisibilityDidChangeNotification = Notification.Name("dev.spill.Spill.aiToolVisibilityDidChange")

    // MARK: General (+General)

    @Published var appLanguage: SpillAppLanguage {
        didSet {
            persist(appLanguage, for: .appLanguage)
            defaults.synchronize()
        }
    }

    @Published var appearanceTheme: SpillAppearanceTheme {
        didSet {
            persist(appearanceTheme, for: .appearanceTheme)
            defaults.synchronize()
        }
    }

    @Published var useSpillAnimation: Bool {
        didSet { persist(useSpillAnimation, for: .useSpillAnimation) }
    }

    /// Seconds between status refreshes. No Preferences control; adjustable through defaults only.
    @Published var refreshInterval: Double {
        didSet {
            let sanitized = SettingKey<Double>.refreshInterval.sanitized(refreshInterval)
            if refreshInterval != sanitized {
                refreshInterval = sanitized
            }
            persist(sanitized, for: .refreshInterval)
        }
    }

    /// Mirrors the system login-item state, which is the source of truth, so it is not persisted.
    @Published var launchAtLogin: Bool

    // MARK: Shortcuts (+Shortcuts)

    @Published var hotKeyEnabled: Bool {
        didSet { persist(hotKeyEnabled, for: .hotKeyEnabled) }
    }

    @Published var windowActionShortcutKeys: [WindowActionKind: WindowActionShortcutKey] {
        didSet { persist(windowActionShortcutKeys, for: .windowActionShortcutKeys) }
    }

    // MARK: Sleep guard (+SleepGuard)

    @Published var sleepGuardKeepsDisplayAwake: Bool {
        didSet { persist(sleepGuardKeepsDisplayAwake, for: .sleepGuardKeepsDisplayAwake) }
    }

    @Published var sleepGuardShowsRemainingInMenuBar: Bool {
        didSet { persist(sleepGuardShowsRemainingInMenuBar, for: .sleepGuardShowsRemainingInMenuBar) }
    }

    @Published var sleepGuardDefaultDuration: SleepGuardDuration {
        didSet { persist(sleepGuardDefaultDuration, for: .sleepGuardDefaultDuration) }
    }

    @Published var sleepGuardAllowsIndefinite: Bool {
        didSet {
            persist(sleepGuardAllowsIndefinite, for: .sleepGuardAllowsIndefinite)
            if !sleepGuardAllowsIndefinite, sleepGuardDefaultDuration.isIndefinite {
                sleepGuardDefaultDuration = .fifteenMinutes
            }
        }
    }

    // MARK: Panel status (+PanelStatus)

    @Published var enabledStatusModules: Set<SpillStatusModule> {
        didSet { persist(enabledStatusModules, for: .enabledStatusModules) }
    }

    @Published var panelStatusValueBold: Bool {
        didSet { persist(panelStatusValueBold, for: .panelStatusValueBold) }
    }

    @Published var panelStatusFontDesign: SpillStatusFontDesign {
        didSet { persist(panelStatusFontDesign, for: .panelStatusFontDesign) }
    }

    @Published var panelStatusValueFontSize: Double {
        didSet { persist(panelStatusValueFontSize, for: .panelStatusValueFontSize) }
    }

    @Published var panelSectionSpacing: Double {
        didSet { persist(panelSectionSpacing, for: .panelSectionSpacing) }
    }

    // MARK: Menu bar (+MenuBar)

    @Published var enabledMenuBarStatusItems: Set<SpillMenuBarStatusItem> {
        didSet { persist(enabledMenuBarStatusItems, for: .enabledMenuBarStatusItems) }
    }

    @Published var menuBarMetricPresentationStyles: [SpillMenuBarStatusItem: MenuBarStatusPresentationStyle] {
        didSet { persist(menuBarMetricPresentationStyles, for: .menuBarMetricPresentationStyles) }
    }

    @Published var menuBarStatusLayoutStyle: MenuBarStatusLayoutStyle {
        didSet { persist(menuBarStatusLayoutStyle, for: .menuBarStatusLayoutStyle) }
    }

    @Published var menuBarStatusCompactMode: Bool {
        didSet { persist(menuBarStatusCompactMode, for: .menuBarStatusCompactMode) }
    }

    @Published var menuBarStatusSplitGroups: Bool {
        didSet { persist(menuBarStatusSplitGroups, for: .menuBarStatusSplitGroups) }
    }

    @Published var menuBarStatusPrecision: MenuBarStatusPrecision {
        didSet { persist(menuBarStatusPrecision, for: .menuBarStatusPrecision) }
    }

    @Published var menuBarStatusHighlightThreshold: MenuBarStatusHighlightThreshold {
        didSet { persist(menuBarStatusHighlightThreshold, for: .menuBarStatusHighlightThreshold) }
    }

    @Published var menuBarStatusFontSize: Double {
        didSet {
            let sanitized = SettingKey<Double>.menuBarStatusFontSize.sanitized(menuBarStatusFontSize)
            if menuBarStatusFontSize != sanitized {
                menuBarStatusFontSize = sanitized
            }
            persist(sanitized, for: .menuBarStatusFontSize)
        }
    }

    @Published var menuBarStatusTextBold: Bool {
        didSet { persist(menuBarStatusTextBold, for: .menuBarStatusTextBold) }
    }

    @Published var menuBarTriggerIconStyle: MenuBarTriggerIconStyle {
        didSet { persist(menuBarTriggerIconStyle, for: .menuBarTriggerIconStyle) }
    }

    @Published var menuBarTokenDisplayMode: MenuBarTokenDisplayMode {
        didSet { persist(menuBarTokenDisplayMode, for: .menuBarTokenDisplayMode) }
    }

    // MARK: Token metering (+TokenMetering)

    @Published var tokenUsageLocalAliases: [String: String] {
        didSet { persist(tokenUsageLocalAliases, for: .tokenUsageLocalAliases) }
    }

    /// Also lists tools beyond the main three. No Preferences control; adjustable through defaults only.
    @Published var tokenUsageShowAdvancedTools: Bool {
        didSet { persist(tokenUsageShowAdvancedTools, for: .tokenUsageShowAdvancedTools) }
    }

    @Published var tokenUsageInputScope: TokenUsageInputScope {
        didSet {
            persist(tokenUsageInputScope, for: .tokenUsageInputScope)
            defaults.synchronize()
        }
    }

    @Published var hiddenTokenUsageAITools: Set<TokenUsageAITool> {
        didSet { persist(hiddenTokenUsageAITools, for: .hiddenTokenUsageAITools) }
    }

    @Published var hiddenLocalAIToolKinds: Set<LocalAIToolKind> {
        didSet { persist(hiddenLocalAIToolKinds, for: .hiddenLocalAIToolKinds) }
    }

    @Published var privateUsageUploadEnvironment: PrivateUsageUploadEnvironment {
        didSet {
            persist(privateUsageUploadEnvironment, for: .privateUsageUploadEnvironment)
            privateUsageUploadEnabled = defaults.value(
                for: .privateUsageUploadEnabled(for: privateUsageUploadEnvironment)
            )
        }
    }

    @Published var privateUsageUploadEnabled: Bool {
        didSet {
            persist(
                privateUsageUploadEnabled,
                for: .privateUsageUploadEnabled(for: privateUsageUploadEnvironment)
            )
        }
    }

    // MARK: Developer

    @Published var tokenUsageDashboardOnboardingPreviewEnabled: Bool {
        didSet {
            persist(
                tokenUsageDashboardOnboardingPreviewEnabled,
                for: .tokenUsageDashboardOnboardingPreviewEnabled
            )
        }
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        appLanguage = defaults.value(for: .appLanguage)
        appearanceTheme = defaults.value(for: .appearanceTheme)
        useSpillAnimation = defaults.value(for: .useSpillAnimation)
        refreshInterval = defaults.value(for: .refreshInterval)
        // Login-item state belongs to the system, not to defaults.
        launchAtLogin = LoginItemController.isEnabled

        hotKeyEnabled = defaults.value(for: .hotKeyEnabled)
        windowActionShortcutKeys = defaults.value(for: .windowActionShortcutKeys)

        let allowsIndefinite = defaults.value(for: .sleepGuardAllowsIndefinite)
        sleepGuardKeepsDisplayAwake = Self.loadSleepGuardKeepsDisplayAwake(from: defaults)
        sleepGuardShowsRemainingInMenuBar = defaults.value(for: .sleepGuardShowsRemainingInMenuBar)
        sleepGuardDefaultDuration = Self.loadSleepGuardDefaultDuration(
            from: defaults,
            allowsIndefinite: allowsIndefinite
        )
        sleepGuardAllowsIndefinite = allowsIndefinite

        enabledStatusModules = Self.loadEnabledStatusModules(from: defaults)
        panelStatusValueBold = defaults.value(for: .panelStatusValueBold)
        panelStatusFontDesign = defaults.value(for: .panelStatusFontDesign)
        panelStatusValueFontSize = defaults.value(for: .panelStatusValueFontSize)
        panelSectionSpacing = defaults.value(for: .panelSectionSpacing)

        enabledMenuBarStatusItems = defaults.value(for: .enabledMenuBarStatusItems)
        menuBarMetricPresentationStyles = Self.loadMenuBarMetricPresentationStyles(from: defaults)
        menuBarStatusLayoutStyle = defaults.value(for: .menuBarStatusLayoutStyle)
        menuBarStatusCompactMode = defaults.value(for: .menuBarStatusCompactMode)
        menuBarStatusSplitGroups = defaults.value(for: .menuBarStatusSplitGroups)
        menuBarStatusPrecision = defaults.value(for: .menuBarStatusPrecision)
        menuBarStatusHighlightThreshold = defaults.value(for: .menuBarStatusHighlightThreshold)
        menuBarStatusFontSize = defaults.value(for: .menuBarStatusFontSize)
        menuBarStatusTextBold = defaults.value(for: .menuBarStatusTextBold)
        menuBarTriggerIconStyle = defaults.value(for: .menuBarTriggerIconStyle)
        menuBarTokenDisplayMode = defaults.value(for: .menuBarTokenDisplayMode)

        tokenUsageLocalAliases = defaults.value(for: .tokenUsageLocalAliases)
        tokenUsageShowAdvancedTools = defaults.value(for: .tokenUsageShowAdvancedTools)
        tokenUsageInputScope = defaults.value(for: .tokenUsageInputScope)
        let aiToolVisibility = Self.loadAIToolVisibility(from: defaults)
        hiddenTokenUsageAITools = aiToolVisibility.hiddenTokenUsageAITools
        hiddenLocalAIToolKinds = aiToolVisibility.hiddenLocalAIToolKinds
        let uploadEnvironment = Self.loadPrivateUsageUploadEnvironment(from: defaults)
        privateUsageUploadEnvironment = uploadEnvironment
        privateUsageUploadEnabled = defaults.value(for: .privateUsageUploadEnabled(for: uploadEnvironment))

        tokenUsageDashboardOnboardingPreviewEnabled = defaults.value(for: .tokenUsageDashboardOnboardingPreviewEnabled)
    }

    private func persist<Value>(_ value: Value, for key: SettingKey<Value>) {
        defaults.store(value, for: key)
    }
}
