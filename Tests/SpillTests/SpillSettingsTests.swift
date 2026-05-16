import XCTest
import CoreGraphics
@testable import Spill

@MainActor
final class SpillSettingsTests: XCTestCase {
    func testStatusModuleSettingsDefaultToAllModulesEnabledInDefaultOrder() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.statusModuleOrder, [.cpu, .memory, .storage])
        XCTAssertEqual(settings.enabledStatusModules, [.cpu, .memory, .storage])
        XCTAssertEqual(settings.enabledMenuBarStatusItems, [.cpu, .memory])
        XCTAssertEqual(settings.menuBarStatusDisplayStyle, .labelAndPercent)
        XCTAssertEqual(settings.menuBarStatusPrecision, .tenths)
        XCTAssertEqual(settings.menuBarStatusHighlightThreshold, .seventy)
        XCTAssertEqual(settings.sleepGuardDefaultDuration, .fifteenMinutes)
        XCTAssertEqual(settings.shortcutKey(for: .leftHalf), .leftArrow)
        XCTAssertEqual(settings.shortcutKey(for: .rightHalf), .rightArrow)
        XCTAssertEqual(settings.shortcutKey(for: .center), .c)
        XCTAssertEqual(settings.shortcutKey(for: .maximize), .returnKey)
        XCTAssertEqual(settings.shortcutKey(for: .nextDisplay), .d)
        XCTAssertEqual(settings.shortcutKey(for: .restore), .r)
    }

    func testPowerFooterDefaultsToVisibleAndSleepGuardDisplayAwakeDefaultsOff() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        XCTAssertTrue(settings.showPowerFooter)
        XCTAssertFalse(settings.sleepGuardKeepsDisplayAwake)
        XCTAssertEqual(settings.sleepGuardDefaultDuration, .fifteenMinutes)
    }

    func testPowerAndSleepGuardSettingsPersist() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.showPowerFooter = false
        settings.sleepGuardKeepsDisplayAwake = true
        settings.sleepGuardDefaultDuration = .oneHour

        XCTAssertFalse(defaults.bool(forKey: "showPowerFooter"))
        XCTAssertTrue(defaults.bool(forKey: "sleepGuardKeepsDisplayAwake"))
        XCTAssertEqual(defaults.integer(forKey: "sleepGuardDefaultDuration"), SleepGuardDuration.oneHour.rawValue)

        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertEqual(reloadedSettings.sleepGuardDefaultDuration, .oneHour)
    }

    func testSleepGuardDefaultDurationNormalizesUnknownValue() {
        let defaults = makeDefaults()
        defaults.set(999, forKey: "sleepGuardDefaultDuration")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.sleepGuardDefaultDuration, .fifteenMinutes)
    }

    func testStatusModuleOrderNormalizesUnknownDuplicateAndMissingValues() {
        let defaults = makeDefaults()
        defaults.set(["memory", "unknown", "memory"], forKey: "statusModuleOrder")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.statusModuleOrder, [.memory, .cpu, .storage])
    }

    func testStatusModuleEnabledStatePersists() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.setStatusModule(.cpu, enabled: false)
        settings.setStatusModule(.network, enabled: true)

        XCTAssertFalse(settings.isStatusModuleEnabled(.cpu))
        XCTAssertTrue(settings.isStatusModuleEnabled(.memory))
        XCTAssertTrue(settings.isStatusModuleEnabled(.storage))
        XCTAssertFalse(settings.isStatusModuleEnabled(.gpu))
        XCTAssertFalse(settings.isStatusModuleEnabled(.network))
        XCTAssertEqual(defaults.stringArray(forKey: "enabledStatusModules"), ["memory", "storage"])
    }

    func testMenuBarStatusItemsPersistAndDriveRefreshRequirements() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.setStatusModule(.network, enabled: false)
        settings.setMenuBarStatusItem(.memory, enabled: false)
        settings.setMenuBarStatusItem(.network, enabled: true)

        XCTAssertTrue(settings.isMenuBarStatusItemEnabled(.cpu))
        XCTAssertFalse(settings.isMenuBarStatusItemEnabled(.memory))
        XCTAssertFalse(settings.isMenuBarStatusItemEnabled(.gpu))
        XCTAssertFalse(settings.isMenuBarStatusItemEnabled(.network))
        XCTAssertFalse(settings.isMenuBarStatusItemEnabled(.ai))
        XCTAssertEqual(defaults.stringArray(forKey: "enabledMenuBarStatusItems"), ["cpu"])
        XCTAssertEqual(settings.statusModulesRequiredForRefresh, [.cpu, .memory, .storage])
    }

    func testLegacyGPUStatusModuleSettingsNormalizeToStorage() {
        let defaults = makeDefaults()
        defaults.set(["gpu", "memory"], forKey: "statusModuleOrder")
        defaults.set(["gpu", "cpu"], forKey: "enabledStatusModules")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.statusModuleOrder, [.memory, .cpu, .storage])
        XCTAssertEqual(settings.enabledStatusModules, [.cpu, .storage])
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
        defaults.set(["ai", "unknown", "cpu"], forKey: "enabledMenuBarStatusItems")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.enabledMenuBarStatusItems, [.cpu])
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
                "center=c",
                "maximize=returnKey",
                "nextDisplay=d",
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
        XCTAssertEqual(settings.shortcutKey(for: .center), .c)
        XCTAssertEqual(settings.shortcutKey(for: .maximize), .returnKey)
    }

    func testStatusModuleOrderPersistsAfterMove() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.moveStatusModule(.memory, direction: -1)

        XCTAssertEqual(settings.statusModuleOrder, [.memory, .cpu, .storage])
        XCTAssertEqual(defaults.stringArray(forKey: "statusModuleOrder"), ["memory", "cpu", "storage"])
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
