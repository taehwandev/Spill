import XCTest
@testable import Spill

/// Stored preference keys are a compatibility contract with every install already in the wild:
/// renaming a property is free, renaming a key silently resets that setting for existing users.
final class SettingKeyTests: XCTestCase {
    func testStoredKeyNamesNeverChange() {
        let names: [String] = [
            SettingKey<SpillAppLanguage>.appLanguage.name,
            SettingKey<SpillAppearanceTheme>.appearanceTheme.name,
            SettingKey<Bool>.useSpillAnimation.name,
            SettingKey<Double>.refreshInterval.name,
            SettingKey<Bool>.hotKeyEnabled.name,
            SettingKey<[WindowActionKind: WindowActionShortcutKey]>.windowActionShortcutKeys.name,
            SettingKey<Bool>.sleepGuardKeepsDisplayAwake.name,
            SettingKey<Bool>.sleepGuardShowsRemainingInMenuBar.name,
            SettingKey<SleepGuardDuration>.sleepGuardDefaultDuration.name,
            SettingKey<Bool>.sleepGuardAllowsIndefinite.name,
            SettingKey<Bool>.sleepGuardDisplayAwakeDefaultMigrated.name,
            SettingKey<Set<SpillStatusModule>>.enabledStatusModules.name,
            SettingKey<Bool>.panelStatusValueBold.name,
            SettingKey<SpillStatusFontDesign>.panelStatusFontDesign.name,
            SettingKey<Double>.panelStatusValueFontSize.name,
            SettingKey<Double>.panelSectionSpacing.name,
            SettingKey<Bool>.statusModuleNetworkDefaultEnabledMigrated.name,
            SettingKey<Bool>.statusModuleGPUDefaultEnabledMigrated.name,
            SettingKey<Set<SpillMenuBarStatusItem>>.enabledMenuBarStatusItems.name,
            SettingKey<[SpillMenuBarStatusItem: MenuBarStatusPresentationStyle]>.menuBarMetricPresentationStyles.name,
            SettingKey<MenuBarStatusPresentationStyle>.legacyMenuBarStatusPresentationStyle.name,
            SettingKey<MenuBarStatusLayoutStyle>.menuBarStatusLayoutStyle.name,
            SettingKey<Bool>.menuBarStatusCompactMode.name,
            SettingKey<Bool>.menuBarStatusSplitGroups.name,
            SettingKey<MenuBarStatusPrecision>.menuBarStatusPrecision.name,
            SettingKey<MenuBarStatusHighlightThreshold>.menuBarStatusHighlightThreshold.name,
            SettingKey<Double>.menuBarStatusFontSize.name,
            SettingKey<Bool>.menuBarStatusTextBold.name,
            SettingKey<MenuBarTriggerIconStyle>.menuBarTriggerIconStyle.name,
            SettingKey<MenuBarTokenDisplayMode>.menuBarTokenDisplayMode.name,
            SettingKey<[String: String]>.tokenUsageLocalAliases.name,
            SettingKey<Bool>.tokenUsageShowAdvancedTools.name,
            SettingKey<TokenUsageInputScope>.tokenUsageInputScope.name,
            SettingKey<Set<TokenUsageAITool>>.hiddenTokenUsageAITools.name,
            SettingKey<Set<LocalAIToolKind>>.hiddenLocalAIToolKinds.name,
            SettingKey<PrivateUsageUploadEnvironment>.privateUsageUploadEnvironment.name,
            SettingKey<Bool>.privateUsageUploadEnabled(for: .production).name,
            SettingKey<Bool>.tokenUsageDashboardOnboardingPreviewEnabled.name
        ]

        XCTAssertEqual(names, [
            "appLanguage", "appearanceTheme", "useSpillAnimation", "refreshInterval",
            "hotKeyEnabled", "windowActionShortcutKeys",
            "sleepGuardKeepsDisplayAwake", "sleepGuardShowsRemainingInMenuBar", "sleepGuardDefaultDuration",
            "sleepGuardAllowsIndefinite", "sleepGuardDisplayAwakeDefaultMigrated",
            "enabledStatusModules", "statusValueBold", "statusFontDesign", "statusValueFontSize",
            "panelSectionSpacing", "statusModuleNetworkDefaultEnabledMigrated",
            "statusModuleGPUDefaultEnabledMigrated",
            "enabledMenuBarStatusItems", "menuBarMetricPresentationStyles", "menuBarStatusPresentationStyle",
            "menuBarStatusLayoutStyle", "menuBarStatusCompactMode", "menuBarStatusSplitGroups",
            "menuBarStatusPrecision", "menuBarStatusHighlightThreshold", "menuBarStatusFontSize",
            "menuBarStatusTextBold", "menuBarTriggerIconStyle", "menuBarTokenDisplayMode",
            "tokenUsageLocalAliases", "tokenUsageShowAdvancedTools", "tokenUsageInputScope",
            "hiddenTokenUsageAITools", "hiddenLocalAIToolKinds", "privateUsageUploadEnvironment",
            "privateUsageUploadEnabled.production", "tokenUsageDashboardOnboardingPreviewEnabled"
        ])
        XCTAssertEqual(Set(names).count, names.count, "Two settings must never share a stored key")
    }

    func testDecodeIsTotalAndFallsBackToTheDefault() {
        XCTAssertEqual(SettingKey<Bool>.useSpillAnimation.decode(nil), true)
        XCTAssertEqual(SettingKey<Bool>.useSpillAnimation.decode("not a bool"), true)
        XCTAssertEqual(SettingKey<MenuBarStatusPrecision>.menuBarStatusPrecision.decode(nil), .tenths)
        XCTAssertEqual(SettingKey<MenuBarStatusPrecision>.menuBarStatusPrecision.decode(999), .tenths)
        XCTAssertEqual(SettingKey<MenuBarTokenDisplayMode>.menuBarTokenDisplayMode.decode("bogus"), .daily)
        XCTAssertEqual(SettingKey<[String: String]>.tokenUsageLocalAliases.decode(7), [:])
        XCTAssertEqual(SettingKey<TokenUsageInputScope>.tokenUsageInputScope.decode(nil), .includeCache)
    }

    func testNumericSettingsAreClampedWhenReadBack() {
        XCTAssertEqual(SettingKey<Double>.refreshInterval.sanitized(1), 5)
        XCTAssertEqual(SettingKey<Double>.refreshInterval.sanitized(.infinity), 15)
        XCTAssertEqual(SettingKey<Double>.refreshInterval.sanitized(60), 60)
        XCTAssertEqual(SettingKey<Double>.menuBarStatusFontSize.sanitized(40), 15)
        XCTAssertEqual(SettingKey<Double>.menuBarStatusFontSize.sanitized(2), 10)
        XCTAssertEqual(SettingKey<Double>.menuBarStatusFontSize.sanitized(.nan), 13.5)
    }

    func testStoredSetsAreWrittenInAStableOrderAndSkipUnknownValues() {
        let hiddenTools = SettingKey<Set<TokenUsageAITool>>.hiddenTokenUsageAITools
        XCTAssertEqual(
            hiddenTools.encode([.claude, .codex]) as? [String],
            ["claude", "codex"],
            "Sorted, so the stored array does not churn between launches"
        )
        XCTAssertEqual(hiddenTools.decode(["codex", "not-a-tool", "openai"]), [.codex])

        let modules = SettingKey<Set<SpillStatusModule>>.enabledStatusModules
        XCTAssertEqual(modules.encode([.network, .cpu]) as? [String], ["cpu", "network"])
    }

    func testEachEnvironmentKeepsItsOwnUploadConsent() {
        let development = SettingKey<Bool>.privateUsageUploadEnabled(for: .development)
        let production = SettingKey<Bool>.privateUsageUploadEnabled(for: .production)

        XCTAssertNotEqual(development.name, production.name)
        XCTAssertEqual(development.decode(nil), false)
    }

    @MainActor
    func testEveryPersistedSettingRoundTripsThroughItsKey() throws {
        let suiteName = "SettingKeyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SpillSettings(defaults: defaults)
        settings.menuBarTokenDisplayMode = .cycle
        settings.panelSectionSpacing = 20
        settings.panelStatusValueBold = false
        settings.refreshInterval = 2

        let reloaded = SpillSettings(defaults: defaults)
        XCTAssertEqual(reloaded.menuBarTokenDisplayMode, .cycle)
        XCTAssertEqual(reloaded.panelSectionSpacing, 20)
        XCTAssertFalse(reloaded.panelStatusValueBold)
        XCTAssertEqual(reloaded.refreshInterval, 5, "A too-small interval is stored as the minimum")
        XCTAssertEqual(defaults.double(forKey: "refreshInterval"), 5)
        XCTAssertEqual(defaults.string(forKey: "menuBarTokenDisplayMode"), "cycle")
        XCTAssertFalse(defaults.bool(forKey: "statusValueBold"), "The renamed property keeps its stored key")
    }
}
