import XCTest
import CoreGraphics
@testable import Spill

@MainActor
final class SpillSettingsTests: XCTestCase {
    func testStatusModuleSettingsDefaultToAllModulesEnabledInDefaultOrder() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.statusModuleOrder, [.cpu, .memory, .storage, .network])
        XCTAssertEqual(settings.enabledStatusModules, [.cpu, .memory, .storage, .network])
        XCTAssertEqual(settings.enabledMenuBarStatusItems, [.cpu, .memory])
        XCTAssertEqual(settings.menuBarStatusDisplayStyle, .labelAndPercent)
        XCTAssertEqual(settings.menuBarStatusPrecision, .tenths)
        XCTAssertEqual(settings.menuBarStatusHighlightThreshold, .seventy)
        XCTAssertEqual(settings.sleepGuardDefaultDuration, .fifteenMinutes)
        XCTAssertFalse(settings.sleepGuardAllowsIndefinite)
        XCTAssertFalse(settings.sleepGuardShowsRemainingInMenuBar)
        XCTAssertFalse(settings.availableSleepGuardDurations.contains(.indefinitely))
        XCTAssertEqual(settings.shortcutKey(for: .leftHalf), .leftArrow)
        XCTAssertEqual(settings.shortcutKey(for: .rightHalf), .rightArrow)
        XCTAssertEqual(settings.shortcutKey(for: .topHalf), .upArrow)
        XCTAssertEqual(settings.shortcutKey(for: .bottomHalf), .downArrow)
        XCTAssertEqual(settings.shortcutKey(for: .center), .c)
        XCTAssertEqual(settings.shortcutKey(for: .maximize), .returnKey)
        XCTAssertEqual(settings.shortcutKey(for: .topLeft), .off)
        XCTAssertEqual(settings.shortcutKey(for: .topRight), .off)
        XCTAssertEqual(settings.shortcutKey(for: .bottomLeft), .off)
        XCTAssertEqual(settings.shortcutKey(for: .bottomRight), .off)
        XCTAssertEqual(settings.shortcutKey(for: .previousDisplay), .leftArrow)
        XCTAssertEqual(settings.shortcutKey(for: .nextDisplay), .rightArrow)
        XCTAssertEqual(settings.shortcutKey(for: .restore), .deleteKey)
        XCTAssertEqual(settings.shortcutKey(for: .topHalf).shortcutLabel, "⌃⌥↑")
        XCTAssertEqual(settings.shortcutKey(for: .bottomHalf).shortcutLabel, "⌃⌥↓")
        XCTAssertEqual(settings.shortcutKey(for: .restore).shortcutLabel, "⌃⌥⌫")
        XCTAssertEqual(
            settings.shortcutKey(for: .previousDisplay).shortcutLabel(with: .display),
            "⌃⌥⌘←"
        )
        XCTAssertEqual(settings.shortcutKey(for: .bottomLeft).pickerTitle, "Off")
    }

    func testPowerFooterDefaultsToVisibleAndSleepGuardDisplayAwakeDefaultsOff() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        XCTAssertTrue(settings.showPowerFooter)
        XCTAssertFalse(settings.sleepGuardKeepsDisplayAwake)
        XCTAssertFalse(settings.sleepGuardShowsRemainingInMenuBar)
        XCTAssertEqual(settings.sleepGuardDefaultDuration, .fifteenMinutes)
        XCTAssertFalse(settings.sleepGuardAllowsIndefinite)
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

        XCTAssertTrue(settings.isMenuBarStatusItemEnabled(.cpu))
        XCTAssertFalse(settings.isMenuBarStatusItemEnabled(.memory))
        XCTAssertTrue(settings.isMenuBarStatusItemEnabled(.caffeine))
        XCTAssertFalse(settings.isMenuBarStatusItemEnabled(.gpu))
        XCTAssertFalse(settings.isMenuBarStatusItemEnabled(.network))
        XCTAssertFalse(settings.isMenuBarStatusItemEnabled(.ai))
        XCTAssertEqual(defaults.stringArray(forKey: "enabledMenuBarStatusItems"), ["cpu", "caffeine"])
        XCTAssertEqual(settings.visiblePanelStatusModules, [.cpu, .storage])
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

        XCTAssertEqual(settings.enabledMenuBarStatusItems, [.cpu, .caffeine])
    }

    func testMenuBarStatusDisplayOptionsPersist() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.menuBarStatusDisplayStyle = .percentOnly
        settings.menuBarStatusPrecision = .tenths
        settings.menuBarStatusHighlightThreshold = .eighty

        XCTAssertEqual(defaults.string(forKey: "menuBarStatusDisplayStyle"), "percentOnly")
        XCTAssertEqual(defaults.integer(forKey: "menuBarStatusPrecision"), 1)
        XCTAssertEqual(defaults.integer(forKey: "menuBarStatusHighlightThreshold"), 80)

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertEqual(reloadedSettings.menuBarStatusDisplayStyle, .percentOnly)
        XCTAssertEqual(reloadedSettings.menuBarStatusPrecision, .tenths)
        XCTAssertEqual(reloadedSettings.menuBarStatusHighlightThreshold, .eighty)
    }

    func testMenuBarStatusDisplayOptionsNormalizeUnknownValues() {
        let defaults = makeDefaults()
        defaults.set("bad-style", forKey: "menuBarStatusDisplayStyle")
        defaults.set(9, forKey: "menuBarStatusPrecision")
        defaults.set(12, forKey: "menuBarStatusHighlightThreshold")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.menuBarStatusDisplayStyle, .labelAndPercent)
        XCTAssertEqual(settings.menuBarStatusPrecision, .tenths)
        XCTAssertEqual(settings.menuBarStatusHighlightThreshold, .seventy)
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
                "topLeft=off",
                "topRight=off",
                "bottomLeft=off",
                "bottomRight=off",
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
        XCTAssertEqual(settings.shortcutKey(for: .topLeft), .off)
        XCTAssertEqual(settings.shortcutKey(for: .topRight), .off)
        XCTAssertEqual(settings.shortcutKey(for: .bottomLeft), .off)
        XCTAssertEqual(settings.shortcutKey(for: .bottomRight), .off)
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
        XCTAssertEqual(settings.shortcutKey(for: .topLeft), .off)
        XCTAssertEqual(settings.shortcutKey(for: .topRight), .off)
        XCTAssertEqual(settings.shortcutKey(for: .bottomLeft), .off)
        XCTAssertEqual(settings.shortcutKey(for: .bottomRight), .off)
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
        XCTAssertEqual(settings.shortcutKey(for: .topLeft), .off)
        XCTAssertEqual(settings.shortcutKey(for: .topRight), .off)
        XCTAssertEqual(settings.shortcutKey(for: .bottomLeft), .off)
        XCTAssertEqual(settings.shortcutKey(for: .bottomRight), .off)
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
