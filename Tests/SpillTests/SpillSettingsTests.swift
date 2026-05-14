import XCTest
@testable import Spill

@MainActor
final class SpillSettingsTests: XCTestCase {
    func testStatusModuleSettingsDefaultToAllModulesEnabledInDefaultOrder() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        XCTAssertEqual(settings.statusModuleOrder, [.cpu, .memory])
        XCTAssertEqual(settings.enabledStatusModules, [.cpu, .memory])
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

        XCTAssertEqual(settings.statusModuleOrder, [.memory, .cpu])
    }

    func testStatusModuleEnabledStatePersists() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.setStatusModule(.cpu, enabled: false)

        XCTAssertFalse(settings.isStatusModuleEnabled(.cpu))
        XCTAssertTrue(settings.isStatusModuleEnabled(.memory))
        XCTAssertEqual(defaults.stringArray(forKey: "enabledStatusModules"), ["memory"])
    }

    func testStatusModuleOrderPersistsAfterMove() {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)

        settings.moveStatusModule(.memory, direction: -1)

        XCTAssertEqual(settings.statusModuleOrder, [.memory, .cpu])
        XCTAssertEqual(defaults.stringArray(forKey: "statusModuleOrder"), ["memory", "cpu"])
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "SpillSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
