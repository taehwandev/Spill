import XCTest
@testable import Spill

@MainActor
final class SpillSettingsTests: XCTestCase {
    func testStatusModuleSettingsDefaultToAllModulesEnabledInDefaultOrder() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.statusModuleOrder, [.cpu, .memory, .gpu, .network])
        XCTAssertEqual(settings.enabledStatusModules, [.cpu, .memory, .gpu, .network])
        XCTAssertEqual(settings.enabledMenuBarStatusItems, [.cpu, .memory])
    }

    func testPowerFooterDefaultsToVisibleAndSleepGuardDisplayAwakeDefaultsOff() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        XCTAssertTrue(settings.showPowerFooter)
        XCTAssertFalse(settings.sleepGuardKeepsDisplayAwake)
    }

    func testPowerAndSleepGuardSettingsPersist() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.showPowerFooter = false
        settings.sleepGuardKeepsDisplayAwake = true

        XCTAssertFalse(defaults.bool(forKey: "showPowerFooter"))
        XCTAssertTrue(defaults.bool(forKey: "sleepGuardKeepsDisplayAwake"))
    }

    func testStatusModuleOrderNormalizesUnknownDuplicateAndMissingValues() {
        let defaults = makeDefaults()
        defaults.set(["memory", "unknown", "memory"], forKey: "statusModuleOrder")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.statusModuleOrder, [.memory, .cpu, .gpu, .network])
    }

    func testStatusModuleEnabledStatePersists() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.setStatusModule(.cpu, enabled: false)

        XCTAssertFalse(settings.isStatusModuleEnabled(.cpu))
        XCTAssertTrue(settings.isStatusModuleEnabled(.memory))
        XCTAssertTrue(settings.isStatusModuleEnabled(.gpu))
        XCTAssertTrue(settings.isStatusModuleEnabled(.network))
        XCTAssertEqual(defaults.stringArray(forKey: "enabledStatusModules"), ["memory", "gpu", "network"])
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
        XCTAssertEqual(settings.statusModulesRequiredForRefresh, [.cpu, .memory, .gpu])
    }

    func testMenuBarStatusItemsNormalizeUnknownValues() {
        let defaults = makeDefaults()
        defaults.set(["ai", "unknown", "cpu"], forKey: "enabledMenuBarStatusItems")

        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.enabledMenuBarStatusItems, [.cpu])
    }

    func testStatusModuleOrderPersistsAfterMove() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.moveStatusModule(.memory, direction: -1)

        XCTAssertEqual(settings.statusModuleOrder, [.memory, .cpu, .gpu, .network])
        XCTAssertEqual(defaults.stringArray(forKey: "statusModuleOrder"), ["memory", "cpu", "gpu", "network"])
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "SpillSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
