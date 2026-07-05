import XCTest
import CoreGraphics
@testable import Spill

@MainActor
final class SpillSettingsTests: XCTestCase {
    func testStatusModuleSettingsDefaultToAllModulesEnabledInDefaultOrder() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.appLanguage, .automatic)
        XCTAssertEqual(settings.statusModuleOrder, [.cpu, .memory, .storage, .network])
        XCTAssertEqual(settings.enabledStatusModules, [.cpu, .memory, .storage, .network])
        XCTAssertEqual(settings.enabledMenuBarStatusItems, [.cpu, .memory])
        XCTAssertFalse(settings.panelOnboardingPreviewEnabled)
        XCTAssertFalse(settings.tokenUsageDashboardOnboardingPreviewEnabled)
        XCTAssertEqual(settings.menuBarStatusLayoutStyle, .inline)
        XCTAssertFalse(settings.menuBarStatusCompactMode)
        XCTAssertFalse(settings.menuBarStatusSplitGroups)
        XCTAssertEqual(settings.menuBarStatusPrecision, .tenths)
        XCTAssertEqual(settings.menuBarStatusHighlightThreshold, .seventy)
        XCTAssertEqual(settings.menuBarStatusFontSize, 13.5)
        XCTAssertFalse(settings.menuBarStatusTextBold)
        XCTAssertEqual(settings.menuBarTriggerIconStyle, .spill)
        XCTAssertEqual(settings.sleepGuardDefaultDuration, .fifteenMinutes)
        XCTAssertFalse(settings.sleepGuardAllowsIndefinite)
        XCTAssertFalse(settings.sleepGuardShowsRemainingInMenuBar)
        XCTAssertTrue(settings.sleepGuardKeepsDisplayAwake)
        XCTAssertFalse(settings.availableSleepGuardDurations.contains(.indefinitely))
        XCTAssertEqual(settings.shortcutKey(for: .leftHalf), .leftArrow)
        XCTAssertEqual(settings.shortcutKey(for: .rightHalf), .rightArrow)
        XCTAssertEqual(settings.shortcutKey(for: .topHalf), .upArrow)
        XCTAssertEqual(settings.shortcutKey(for: .bottomHalf), .downArrow)
        XCTAssertEqual(settings.shortcutKey(for: .center), .c)
        XCTAssertEqual(settings.shortcutKey(for: .maximize), .returnKey)
        XCTAssertEqual(settings.shortcutKey(for: .topLeft), .u)
        XCTAssertEqual(settings.shortcutKey(for: .topRight), .i)
        XCTAssertEqual(settings.shortcutKey(for: .bottomLeft), .j)
        XCTAssertEqual(settings.shortcutKey(for: .bottomRight), .k)
        XCTAssertEqual(settings.shortcutKey(for: .previousDisplay), .leftArrow)
        XCTAssertEqual(settings.shortcutKey(for: .nextDisplay), .rightArrow)
        XCTAssertEqual(settings.shortcutKey(for: .restore), .deleteKey)
        XCTAssertEqual(settings.shortcutKey(for: .topHalf).shortcutLabel, "⌃⌥↑")
        XCTAssertEqual(settings.shortcutKey(for: .bottomHalf).shortcutLabel, "⌃⌥↓")
        XCTAssertEqual(settings.privateUsageUploadEnvironment, .defaultValue)
        XCTAssertFalse(settings.privateUsageUploadEnabled)
        XCTAssertEqual(settings.shortcutKey(for: .restore).shortcutLabel, "⌃⌥⌫")
        XCTAssertEqual(
            settings.shortcutKey(for: .previousDisplay).shortcutLabel(with: .display),
            "⌃⌥⌘←"
        )
        XCTAssertEqual(settings.shortcutKey(for: .bottomLeft).pickerTitle, "J")
    }

    func testPrivateUsageUploadOptionPersists() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        XCTAssertFalse(settings.privateUsageUploadEnabled)

        settings.privateUsageUploadEnabled = true

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertTrue(reloadedSettings.privateUsageUploadEnabled)
    }

    func testHiddenTokenUsageAIToolsPersistAndNormalizeUnknownValues() {
        let defaults = makeDefaults()
        defaults.set(["claude", "openai", "unknown", "claude"], forKey: "hiddenTokenUsageAITools")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertTrue(settings.isTokenUsageAIToolVisible(.codex))
        XCTAssertFalse(settings.isTokenUsageAIToolVisible(.claude))
        XCTAssertTrue(settings.isTokenUsageAIToolVisible(.openAI))
        XCTAssertEqual(settings.hiddenTokenUsageAITools, [.claude])

        settings.setTokenUsageAITool(.antigravity, isVisible: false)
        settings.setTokenUsageAITool(.claude, isVisible: true)
        settings.setLocalAITool(.ollama, isVisible: false)

        XCTAssertTrue(settings.isTokenUsageAIToolVisible(.claude))
        XCTAssertFalse(settings.isTokenUsageAIToolVisible(.antigravity))
        XCTAssertFalse(settings.isLocalAIToolVisible(.antigravity))
        XCTAssertFalse(settings.isLocalAIToolVisible(.ollama))
        XCTAssertEqual(defaults.stringArray(forKey: "hiddenTokenUsageAITools"), ["antigravity"])
        XCTAssertEqual(defaults.stringArray(forKey: "hiddenLocalAIToolKinds"), ["antigravity", "ollama"])

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertTrue(reloadedSettings.isTokenUsageAIToolVisible(.claude))
        XCTAssertFalse(reloadedSettings.isTokenUsageAIToolVisible(.antigravity))
        XCTAssertFalse(reloadedSettings.isLocalAIToolVisible(.ollama))
    }

    func testPrivateUsageUploadOptionIsScopedByEnvironment() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.privateUsageUploadEnvironment = .production
        settings.privateUsageUploadEnabled = true
        settings.privateUsageUploadEnvironment = .development

        XCTAssertFalse(settings.privateUsageUploadEnabled)

        settings.privateUsageUploadEnabled = true
        settings.privateUsageUploadEnvironment = .production

        XCTAssertTrue(settings.privateUsageUploadEnabled)

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertEqual(reloadedSettings.privateUsageUploadEnvironment, .production)
        XCTAssertTrue(reloadedSettings.privateUsageUploadEnabled)

        reloadedSettings.privateUsageUploadEnvironment = .development
        XCTAssertTrue(reloadedSettings.privateUsageUploadEnabled)
    }

    func testPowerFooterDefaultsToVisibleAndSleepGuardDisplayAwakeDefaultsOn() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        XCTAssertTrue(settings.showPowerFooter)
        XCTAssertTrue(settings.sleepGuardKeepsDisplayAwake)
        XCTAssertFalse(settings.sleepGuardShowsRemainingInMenuBar)
        XCTAssertEqual(settings.sleepGuardDefaultDuration, .fifteenMinutes)
        XCTAssertFalse(settings.sleepGuardAllowsIndefinite)
    }

    func testLegacySleepGuardDisplayAwakeFalseMigratesToOn() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: "sleepGuardKeepsDisplayAwake")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertTrue(settings.sleepGuardKeepsDisplayAwake)
        XCTAssertTrue(defaults.bool(forKey: "sleepGuardKeepsDisplayAwake"))
        XCTAssertTrue(defaults.bool(forKey: "sleepGuardDisplayAwakeDefaultMigrated"))
    }

    func testSleepGuardDisplayAwakeCanBeDisabledAfterMigration() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "sleepGuardDisplayAwakeDefaultMigrated")
        defaults.set(false, forKey: "sleepGuardKeepsDisplayAwake")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertFalse(settings.sleepGuardKeepsDisplayAwake)
    }

    func testNumericLayoutSettingsNormalizeNonFiniteDefaults() {
        let defaults = makeDefaults()
        defaults.set(Double.nan, forKey: "iconSpacing")
        defaults.set(Double.infinity, forKey: "refreshInterval")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.iconSpacing, 8)
        XCTAssertEqual(settings.refreshInterval, 15)
    }

    func testNumericLayoutSettingsClampAssignedValues() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.iconSpacing = .nan
        settings.refreshInterval = -1

        XCTAssertEqual(settings.iconSpacing, 8)
        XCTAssertEqual(settings.refreshInterval, 5)
        XCTAssertEqual(defaults.double(forKey: "iconSpacing"), 8)
        XCTAssertEqual(defaults.double(forKey: "refreshInterval"), 5)
    }

    func testPowerAndSleepGuardSettingsPersist() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.showPowerFooter = false
        settings.sleepGuardKeepsDisplayAwake = true
        settings.sleepGuardShowsRemainingInMenuBar = true
        settings.sleepGuardAllowsIndefinite = true
        settings.sleepGuardDefaultDuration = .indefinitely

        XCTAssertFalse(defaults.bool(forKey: "showPowerFooter"))
        XCTAssertTrue(defaults.bool(forKey: "sleepGuardKeepsDisplayAwake"))
        XCTAssertTrue(defaults.bool(forKey: "sleepGuardShowsRemainingInMenuBar"))
        XCTAssertTrue(defaults.bool(forKey: "sleepGuardAllowsIndefinite"))
        XCTAssertEqual(defaults.integer(forKey: "sleepGuardDefaultDuration"), SleepGuardDuration.indefinitely.rawValue)

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertEqual(reloadedSettings.sleepGuardDefaultDuration, .indefinitely)
        XCTAssertTrue(reloadedSettings.sleepGuardShowsRemainingInMenuBar)
        XCTAssertTrue(reloadedSettings.sleepGuardAllowsIndefinite)
    }

    func testSleepGuardDefaultDurationNormalizesUnknownValue() {
        let defaults = makeDefaults()
        defaults.set(999, forKey: "sleepGuardDefaultDuration")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.sleepGuardDefaultDuration, .fifteenMinutes)
    }

    func testIndefiniteSleepGuardDurationRequiresWarningFlag() {
        let defaults = makeDefaults()
        defaults.set(SleepGuardDuration.indefinitely.rawValue, forKey: "sleepGuardDefaultDuration")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.sleepGuardDefaultDuration, .fifteenMinutes)
        XCTAssertFalse(settings.availableSleepGuardDurations.contains(.indefinitely))

        let allowedDefaults = makeDefaults()
        allowedDefaults.set(true, forKey: "sleepGuardAllowsIndefinite")
        allowedDefaults.set(SleepGuardDuration.indefinitely.rawValue, forKey: "sleepGuardDefaultDuration")

        let allowedSettings = SpillSettings(defaults: allowedDefaults)

        XCTAssertEqual(allowedSettings.sleepGuardDefaultDuration, .indefinitely)
        XCTAssertTrue(allowedSettings.availableSleepGuardDurations.contains(.indefinitely))

        allowedSettings.sleepGuardAllowsIndefinite = false

        XCTAssertEqual(allowedSettings.sleepGuardDefaultDuration, .fifteenMinutes)
        XCTAssertFalse(allowedSettings.availableSleepGuardDurations.contains(.indefinitely))
    }

    func testStatusModuleOrderNormalizesUnknownDuplicateAndMissingValues() {
        let defaults = makeDefaults()
        defaults.set(["memory", "unknown", "memory"], forKey: "statusModuleOrder")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.statusModuleOrder, [.memory, .cpu, .storage, .network])
    }

    func testStatusModuleEnabledStatePersists() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.setStatusModule(.cpu, enabled: false)
        settings.setStatusModule(.network, enabled: false)

        XCTAssertFalse(settings.isStatusModuleEnabled(.cpu))
        XCTAssertTrue(settings.isStatusModuleEnabled(.memory))
        XCTAssertTrue(settings.isStatusModuleEnabled(.storage))
        XCTAssertFalse(settings.isStatusModuleEnabled(.gpu))
        XCTAssertFalse(settings.isStatusModuleEnabled(.network))
        XCTAssertEqual(defaults.stringArray(forKey: "enabledStatusModules"), ["memory", "storage"])

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertFalse(reloadedSettings.isStatusModuleEnabled(.network))
    }

    func testLegacyEnabledStatusModulesMigrateNetworkDefaultOnce() {
        let defaults = makeDefaults()
        defaults.set(["cpu", "memory", "storage"], forKey: "enabledStatusModules")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertTrue(settings.isStatusModuleEnabled(.network))
        XCTAssertEqual(defaults.stringArray(forKey: "enabledStatusModules"), ["cpu", "memory", "storage", "network"])

        settings.setStatusModule(.network, enabled: false)

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertFalse(reloadedSettings.isStatusModuleEnabled(.network))
        XCTAssertEqual(defaults.stringArray(forKey: "enabledStatusModules"), ["cpu", "memory", "storage"])
    }

    func testMenuBarStatusItemsPersistAndDriveRefreshRequirements() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.setStatusModule(.memory, enabled: false)
        settings.setStatusModule(.network, enabled: false)
        settings.setMenuBarStatusItem(.memory, enabled: false)
        settings.setMenuBarStatusItem(.caffeine, enabled: true)
        settings.setMenuBarStatusItem(.network, enabled: true)
        settings.setMenuBarStatusItem(.ai, enabled: true)

        XCTAssertTrue(settings.isMenuBarStatusItemEnabled(.cpu))
        XCTAssertFalse(settings.isMenuBarStatusItemEnabled(.memory))
        XCTAssertTrue(settings.isMenuBarStatusItemEnabled(.caffeine))
        XCTAssertFalse(settings.isMenuBarStatusItemEnabled(.gpu))
        XCTAssertFalse(settings.isMenuBarStatusItemEnabled(.network))
        XCTAssertTrue(settings.isMenuBarStatusItemEnabled(.ai))
        XCTAssertEqual(defaults.stringArray(forKey: "enabledMenuBarStatusItems"), ["cpu", "caffeine", "ai"])
        XCTAssertEqual(settings.visiblePanelStatusModules, [.cpu, .storage])
        XCTAssertEqual(settings.statusModulesRequiredForRefresh, [.cpu, .storage])

        settings.menuBarTriggerIconStyle = .spill

        XCTAssertEqual(settings.statusModulesRequiredForRefresh, [.cpu, .storage])
    }

    func testMenuBarStatusKeepsDisabledPanelModuleRefreshingWhenShownInMenuBar() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.setStatusModule(.memory, enabled: false)

        XCTAssertTrue(settings.isMenuBarStatusItemEnabled(.memory))
        XCTAssertEqual(settings.visiblePanelStatusModules, [.cpu, .storage, .network])
        XCTAssertEqual(settings.statusModulesRequiredForRefresh, [.cpu, .memory, .storage, .network])
    }

    func testLegacyGPUStatusModuleSettingsNormalizeToStorage() {
        let defaults = makeDefaults()
        defaults.set(["gpu", "memory"], forKey: "statusModuleOrder")
        defaults.set(["gpu", "cpu"], forKey: "enabledStatusModules")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.statusModuleOrder, [.memory, .cpu, .storage, .network])
        XCTAssertEqual(settings.enabledStatusModules, [.cpu, .storage, .network])
        XCTAssertFalse(settings.isStatusModuleEnabled(.gpu))
    }

    func testHiddenItemsPersistAndAreRestoredWhenSelectedAgain() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)
        let item = makeSnapshot(stableKey: "com.example.status")

        settings.setItem(item, selected: true)
        settings.hideItem(item)

        XCTAssertFalse(settings.selectedItemKeys.contains(item.stableKey))
        XCTAssertTrue(settings.isItemHidden(item))
        XCTAssertEqual(defaults.stringArray(forKey: "hiddenItemKeys"), [item.stableKey])

        settings.setItem(item, selected: true)

        XCTAssertTrue(settings.selectedItemKeys.contains(item.stableKey))
        XCTAssertFalse(settings.isItemHidden(item))

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertEqual(reloadedSettings.selectedItemKeys, [item.stableKey])
        XCTAssertFalse(reloadedSettings.isItemHidden(item))
    }

    func testMenuBarStatusItemsNormalizeUnknownValues() {
        let defaults = makeDefaults()
        defaults.set(["caffeine", "ai", "unknown", "cpu"], forKey: "enabledMenuBarStatusItems")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.enabledMenuBarStatusItems, [.cpu, .caffeine, .ai])
    }

    func testDisplayModePersists() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.displayMode = .selectedItems

        XCTAssertEqual(defaults.string(forKey: "displayMode"), "selectedItems")
        XCTAssertEqual(SpillSettings(defaults: defaults).displayMode, .selectedItems)
    }

    func testMenuBarStatusOptionsPersist() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.menuBarStatusLayoutStyle = .stacked
        settings.menuBarStatusCompactMode = true
        settings.menuBarStatusSplitGroups = true
        settings.menuBarStatusPrecision = .tenths
        settings.menuBarStatusHighlightThreshold = .ninety
        settings.menuBarStatusFontSize = 14.5
        settings.menuBarStatusTextBold = true
        settings.menuBarTriggerIconStyle = .spill

        XCTAssertEqual(defaults.string(forKey: "menuBarStatusLayoutStyle"), "stacked")
        XCTAssertTrue(defaults.bool(forKey: "menuBarStatusCompactMode"))
        XCTAssertTrue(defaults.bool(forKey: "menuBarStatusSplitGroups"))
        XCTAssertEqual(defaults.integer(forKey: "menuBarStatusPrecision"), 1)
        XCTAssertEqual(defaults.integer(forKey: "menuBarStatusHighlightThreshold"), 90)
        XCTAssertEqual(defaults.double(forKey: "menuBarStatusFontSize"), 14.5)
        XCTAssertTrue(defaults.bool(forKey: "menuBarStatusTextBold"))
        XCTAssertEqual(defaults.string(forKey: "menuBarTriggerIconStyle"), "spill")

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertEqual(reloadedSettings.menuBarStatusLayoutStyle, .stacked)
        XCTAssertTrue(reloadedSettings.menuBarStatusCompactMode)
        XCTAssertTrue(reloadedSettings.menuBarStatusSplitGroups)
        XCTAssertEqual(reloadedSettings.menuBarStatusPrecision, .tenths)
        XCTAssertEqual(reloadedSettings.menuBarStatusHighlightThreshold, .ninety)
        XCTAssertEqual(reloadedSettings.menuBarStatusFontSize, 14.5)
        XCTAssertTrue(reloadedSettings.menuBarStatusTextBold)
        XCTAssertEqual(reloadedSettings.menuBarTriggerIconStyle, .spill)
    }

    func testAppLanguagePersistsAndNormalizesUnknownValues() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.appLanguage = .korean

        XCTAssertEqual(defaults.string(forKey: SpillAppLanguage.defaultsKey), "korean")
        XCTAssertEqual(SpillSettings(defaults: defaults).appLanguage, .korean)

        defaults.set("bad-language", forKey: SpillAppLanguage.defaultsKey)

        XCTAssertEqual(SpillSettings(defaults: defaults).appLanguage, .automatic)
    }

    func testAppLanguageReloadsExternalDefaultChanges() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.appLanguage = .english
        defaults.set(SpillAppLanguage.korean.rawValue, forKey: SpillAppLanguage.defaultsKey)

        XCTAssertEqual(settings.appLanguage, .english)

        settings.reloadAppLanguageFromDefaults()

        XCTAssertEqual(settings.appLanguage, .korean)
    }

    func testDashboardHelperUsesMainAppDefaultsDomain() {
        XCTAssertNil(SpillSettings.sharedDefaultsSuiteName(
            bundleIdentifier: "dev.spill.Spill",
            arguments: [],
            environment: [:]
        ))
        XCTAssertEqual(
            SpillSettings.sharedDefaultsSuiteName(
                bundleIdentifier: "dev.spill.Spill.TokenDashboard",
                arguments: [],
                environment: [:]
            ),
            "dev.spill.Spill"
        )
        XCTAssertEqual(
            SpillSettings.sharedDefaultsSuiteName(
                bundleIdentifier: "dev.spill.Spill.TokenDashboard",
                arguments: [TokenMeteringDashboardProcess.standaloneArgument],
                environment: [TokenMeteringDashboardProcess.mainBundleIdentifierEnvironmentKey: "com.example.Spill"]
            ),
            "com.example.Spill"
        )
    }

    func testPreferencesLocalizationCoversSupportedLanguages() {
        XCTAssertEqual(
            PreferencesL10n.text(.preferencesWindowTitle, appLanguage: .english),
            "Spill Preferences"
        )
        XCTAssertEqual(PreferencesL10n.text(.general, appLanguage: .korean), "일반")
        XCTAssertEqual(PreferencesL10n.text(.menuBarAndNotch, appLanguage: .japanese), "メニューバー")
        XCTAssertEqual(
            PreferencesL10n.languageDetail(.automatic, appLanguage: .korean),
            "macOS 언어를 따릅니다"
        )
        XCTAssertEqual(
            PreferencesL10n.itemCount(3, appLanguage: .japanese),
            "3件"
        )
        XCTAssertEqual(
            PreferencesL10n.upToDate(version: "1.2.3", appLanguage: .korean),
            "Spill은 최신 상태입니다 (1.2.3)."
        )
        XCTAssertEqual(PreferencesL10n.text(.inline, appLanguage: .korean), "가로")
        XCTAssertEqual(PreferencesL10n.text(.clockAreaStatus, appLanguage: .korean), "시계 옆 상태")
        XCTAssertEqual(PreferencesL10n.text(.clockAreaTextSize, appLanguage: .korean), "시계 옆 텍스트 크기")
        XCTAssertEqual(PreferencesL10n.text(.iconOnly, appLanguage: .japanese), "アイコンのみ")
    }

    func testAppLocalizationCoversNativeShellAndPanelText() {
        XCTAssertEqual(AppL10n.text(.showSpillPanel, appLanguage: .english), "Show Spill Panel")
        XCTAssertEqual(AppL10n.text(.showSpillPanel, appLanguage: .korean), "Spill 패널 보기")
        XCTAssertEqual(AppL10n.text(.statusDetails, appLanguage: .japanese), "状態詳細")
        XCTAssertEqual(AppL10n.text(.webSyncEnabled, appLanguage: .english), "Web sync on")
        XCTAssertEqual(AppL10n.text(.webSyncEnabled, appLanguage: .korean), "웹 동기화 켜짐")
        XCTAssertEqual(AppL10n.sleepDurationTitle(.fifteenMinutes, appLanguage: .korean), "15분")
        XCTAssertEqual(AppL10n.statusModuleTitle(.memory, appLanguage: .japanese), "メモリ")
        XCTAssertEqual(
            AppL10n.eventsSummary(eventCount: 2, task: "코드 작성 10", source: "출력 5", appLanguage: .korean),
            "기록 2개 / 코드 작성 10 / 출력 5"
        )
        XCTAssertEqual(
            AppL10n.eventsSummary(eventCount: 10_000, task: "Analysis 10K", source: "AI response 1K", appLanguage: .english),
            "10,000 records / Analysis 10K / AI response 1K"
        )
        XCTAssertEqual(
            AppL10n.eventsSummary(eventCount: 115_328, task: "분석 10K", source: "응답 1K", appLanguage: .korean),
            "기록 115,328개 / 분석 10K / 응답 1K"
        )
        XCTAssertEqual(AppL10n.text(.scanningMenuBarItems, appLanguage: .korean), "메뉴 막대 항목 스캔 중...")
        XCTAssertEqual(AppL10n.windowActionTitle(.restore, appLanguage: .japanese), "復元")
        XCTAssertEqual(AppL10n.pinned("Raycast", appLanguage: .korean), "Raycast 고정됨")
    }

    func testPanelOnboardingPreviewSettingPersists() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.panelOnboardingPreviewEnabled = true
        settings.tokenUsageDashboardOnboardingPreviewEnabled = true

        XCTAssertTrue(defaults.bool(forKey: "panelOnboardingPreviewEnabled"))
        XCTAssertTrue(defaults.bool(forKey: "tokenUsageDashboardOnboardingPreviewEnabled"))

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertTrue(reloadedSettings.panelOnboardingPreviewEnabled)
        XCTAssertTrue(reloadedSettings.tokenUsageDashboardOnboardingPreviewEnabled)
    }

    func testMenuBarStatusOptionsNormalizeUnknownValues() {
        let defaults = makeDefaults()
        defaults.set("bad-layout", forKey: "menuBarStatusLayoutStyle")
        defaults.set(9, forKey: "menuBarStatusPrecision")
        defaults.set(12, forKey: "menuBarStatusHighlightThreshold")
        defaults.set(Double.nan, forKey: "menuBarStatusFontSize")
        defaults.set("bad-trigger", forKey: "menuBarTriggerIconStyle")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.menuBarStatusLayoutStyle, .inline)
        XCTAssertEqual(settings.menuBarStatusPrecision, .tenths)
        XCTAssertEqual(settings.menuBarStatusHighlightThreshold, .seventy)
        XCTAssertEqual(settings.menuBarStatusFontSize, 13.5)
        XCTAssertEqual(settings.menuBarTriggerIconStyle, .spill)
    }

    func testMenuBarTriggerIconStylesExposeDropSymbolOption() {
        XCTAssertEqual(MenuBarTriggerIconStyle.selectableCases, [.spill])
        XCTAssertEqual(MenuBarTriggerIconStyle.spill.title, "Drop")
        XCTAssertEqual(MenuBarTriggerIconStyle.normalized(rawValue: "spill"), .spill)
        XCTAssertEqual(MenuBarTriggerIconStyle.normalized(rawValue: "cat"), .spill)
        XCTAssertEqual(MenuBarTriggerIconStyle.normalized(rawValue: "liquid"), .spill)

        let defaults = makeDefaults()
        defaults.set("spill", forKey: "menuBarTriggerIconStyle")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.menuBarTriggerIconStyle, .spill)
    }

    func testWindowActionShortcutsPersistAndResolveConflicts() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.setWindowActionShortcut(.one, for: .leftHalf)
        settings.setWindowActionShortcut(.one, for: .rightHalf)
        settings.setWindowActionShortcut(.off, for: .restore)

        XCTAssertEqual(settings.shortcutKey(for: .leftHalf), .off)
        XCTAssertEqual(settings.shortcutKey(for: .rightHalf), .one)
        XCTAssertEqual(settings.shortcutKey(for: .restore), .off)
        XCTAssertEqual(
            defaults.stringArray(forKey: "windowActionShortcutKeys"),
            [
                "leftHalf=off",
                "rightHalf=one",
                "topHalf=upArrow",
                "bottomHalf=downArrow",
                "center=c",
                "maximize=returnKey",
                "topLeft=u",
                "topRight=i",
                "bottomLeft=j",
                "bottomRight=k",
                "previousDisplay=leftArrow",
                "nextDisplay=rightArrow",
                "restore=off"
            ]
        )

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertEqual(reloadedSettings.shortcutKey(for: .leftHalf), .off)
        XCTAssertEqual(reloadedSettings.shortcutKey(for: .rightHalf), .one)
        XCTAssertEqual(reloadedSettings.shortcutKey(for: .restore), .off)
    }

    func testWindowActionShortcutsNormalizeUnknownAndDuplicateValues() {
        let defaults = makeDefaults()
        defaults.set(
            [
                "leftHalf=two",
                "rightHalf=two",
                "center=bad",
                "unknown=three"
            ],
            forKey: "windowActionShortcutKeys"
        )

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.shortcutKey(for: .leftHalf), .two)
        XCTAssertEqual(settings.shortcutKey(for: .rightHalf), .off)
        XCTAssertEqual(settings.shortcutKey(for: .topHalf), .upArrow)
        XCTAssertEqual(settings.shortcutKey(for: .bottomHalf), .downArrow)
        XCTAssertEqual(settings.shortcutKey(for: .center), .c)
        XCTAssertEqual(settings.shortcutKey(for: .maximize), .returnKey)
        XCTAssertEqual(settings.shortcutKey(for: .topLeft), .u)
        XCTAssertEqual(settings.shortcutKey(for: .topRight), .i)
        XCTAssertEqual(settings.shortcutKey(for: .bottomLeft), .j)
        XCTAssertEqual(settings.shortcutKey(for: .bottomRight), .k)
        XCTAssertEqual(settings.shortcutKey(for: .previousDisplay), .leftArrow)
        XCTAssertEqual(settings.shortcutKey(for: .nextDisplay), .rightArrow)
    }

    func testLegacyWindowActionDefaultsMigrateToCommonShortcuts() {
        let defaults = makeDefaults()
        defaults.set(
            [
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
            ],
            forKey: "windowActionShortcutKeys"
        )

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.shortcutKey(for: .topHalf), .upArrow)
        XCTAssertEqual(settings.shortcutKey(for: .bottomHalf), .downArrow)
        XCTAssertEqual(settings.shortcutKey(for: .topLeft), .u)
        XCTAssertEqual(settings.shortcutKey(for: .topRight), .i)
        XCTAssertEqual(settings.shortcutKey(for: .bottomLeft), .j)
        XCTAssertEqual(settings.shortcutKey(for: .bottomRight), .k)
        XCTAssertEqual(settings.shortcutKey(for: .previousDisplay), .leftArrow)
        XCTAssertEqual(settings.shortcutKey(for: .nextDisplay), .rightArrow)
        XCTAssertEqual(settings.shortcutKey(for: .restore), .deleteKey)
    }

    func testPreviousWindowActionDefaultsMigrateToArrowOnlyMovementShortcuts() {
        let defaults = makeDefaults()
        defaults.set(
            [
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
            ],
            forKey: "windowActionShortcutKeys"
        )

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.shortcutKey(for: .leftHalf), .leftArrow)
        XCTAssertEqual(settings.shortcutKey(for: .rightHalf), .rightArrow)
        XCTAssertEqual(settings.shortcutKey(for: .topHalf), .upArrow)
        XCTAssertEqual(settings.shortcutKey(for: .bottomHalf), .downArrow)
        XCTAssertEqual(settings.shortcutKey(for: .topLeft), .u)
        XCTAssertEqual(settings.shortcutKey(for: .topRight), .i)
        XCTAssertEqual(settings.shortcutKey(for: .bottomLeft), .j)
        XCTAssertEqual(settings.shortcutKey(for: .bottomRight), .k)
        XCTAssertEqual(settings.shortcutKey(for: .previousDisplay), .leftArrow)
        XCTAssertEqual(settings.shortcutKey(for: .nextDisplay), .rightArrow)
        XCTAssertEqual(settings.shortcutKey(for: .restore), .deleteKey)
    }

    func testWindowActionShortcutConflictsAreScopedToModifierGroup() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.setWindowActionShortcut(.leftArrow, for: .previousDisplay)

        XCTAssertEqual(settings.shortcutKey(for: .leftHalf), .leftArrow)
        XCTAssertEqual(settings.shortcutKey(for: .previousDisplay), .leftArrow)

        settings.setWindowActionShortcut(.leftArrow, for: .rightHalf)

        XCTAssertEqual(settings.shortcutKey(for: .leftHalf), .off)
        XCTAssertEqual(settings.shortcutKey(for: .rightHalf), .leftArrow)
        XCTAssertEqual(settings.shortcutKey(for: .previousDisplay), .leftArrow)
    }

    func testStatusModuleOrderPersistsAfterMove() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.moveStatusModule(.memory, direction: -1)

        XCTAssertEqual(settings.statusModuleOrder, [.memory, .cpu, .storage, .network])
        XCTAssertEqual(defaults.stringArray(forKey: "statusModuleOrder"), ["memory", "cpu", "storage", "network"])
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "SpillSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeSnapshot(stableKey: String) -> MenuBarItemSnapshot {
        MenuBarItemSnapshot(
            id: stableKey,
            stableKey: stableKey,
            ownerName: "Example",
            bundleIdentifier: "com.example",
            processIdentifier: 100,
            title: "Example",
            role: "AXMenuBarItem",
            subrole: nil,
            frame: .zero,
            imageData: nil,
            isNotchCandidate: true,
            canPress: true
        )
    }
}
