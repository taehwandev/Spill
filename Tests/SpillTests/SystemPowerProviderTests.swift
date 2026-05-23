import XCTest
@testable import Spill

final class SystemPowerProviderTests: XCTestCase {
    func testNormalBatteryStatusMapping() {
        let status = SystemPowerProvider.status(
            from: makeReading(currentCapacity: 74, maxCapacity: 100, isACPowered: false)
        )

        XCTAssertEqual(status.value, "74%")
        XCTAssertEqual(status.subtitle, "On Battery")
        XCTAssertEqual(status.chargeRatio, 0.74, accuracy: 0.0001)
        XCTAssertEqual(status.state, .normal)
        XCTAssertEqual(status.symbolName, "battery.100")
        XCTAssertTrue(status.hasBattery)
        XCTAssertFalse(status.isCharging)
        XCTAssertFalse(status.isACPowered)
    }

    func testLowBatteryOnBatteryPowerIsWarning() {
        let status = SystemPowerProvider.status(
            from: makeReading(currentCapacity: 15, maxCapacity: 100, isACPowered: false)
        )

        XCTAssertEqual(status.value, "15%")
        XCTAssertEqual(status.state, .warning)
        XCTAssertEqual(status.symbolName, "battery.25")
    }

    func testChargingBatteryIsActive() {
        let status = SystemPowerProvider.status(
            from: makeReading(currentCapacity: 42, maxCapacity: 100, isCharging: true, isACPowered: true)
        )

        XCTAssertEqual(status.value, "42%")
        XCTAssertEqual(status.subtitle, "Charging")
        XCTAssertEqual(status.state, .active)
        XCTAssertEqual(status.symbolName, "bolt.fill")
        XCTAssertTrue(status.isCharging)
        XCTAssertTrue(status.isACPowered)
    }

    func testBatteryOnExternalPowerUsesNormalState() {
        let status = SystemPowerProvider.status(
            from: makeReading(currentCapacity: 12, maxCapacity: 100, isACPowered: true)
        )

        XCTAssertEqual(status.value, "12%")
        XCTAssertEqual(status.subtitle, "On Power")
        XCTAssertEqual(status.state, .normal)
    }

    func testExternalPowerWithoutBattery() {
        let status = SystemPowerProvider.status(
            from: SystemPowerReading(
                currentCapacity: nil,
                maxCapacity: nil,
                isCharging: false,
                isACPowered: true,
                hasBattery: false
            )
        )

        XCTAssertEqual(status.value, "AC")
        XCTAssertEqual(status.subtitle, "External Power")
        XCTAssertEqual(status.chargeRatio, 1)
        XCTAssertEqual(status.state, .normal)
        XCTAssertEqual(status.symbolName, "powerplug.fill")
        XCTAssertFalse(status.hasBattery)
    }

    func testUnavailablePowerStatusWhenReadingIsMissing() {
        let status = SystemPowerProvider.status(from: nil)

        XCTAssertEqual(status.value, "N/A")
        XCTAssertNil(status.subtitle)
        XCTAssertEqual(status.chargeRatio, 0)
        XCTAssertEqual(status.state, .unavailable)
        XCTAssertEqual(status.symbolName, "powerplug")
        XCTAssertEqual(status.statusItem.state, .unavailable)
    }

    func testUnavailablePowerStatusWhenCapacityIsInvalid() {
        let status = SystemPowerProvider.status(
            from: makeReading(currentCapacity: 10, maxCapacity: 0, isACPowered: false)
        )

        XCTAssertEqual(status.value, "N/A")
        XCTAssertEqual(status.state, .unavailable)
    }

    func testUnavailablePowerStatusWhenCurrentCapacityIsNegative() {
        let status = SystemPowerProvider.status(
            from: makeReading(currentCapacity: -1, maxCapacity: 100, isACPowered: false)
        )

        XCTAssertEqual(status.value, "N/A")
        XCTAssertEqual(status.state, .unavailable)
    }

    func testPowerStatusClampsChargeRatio() {
        let status = SystemPowerProvider.status(
            from: makeReading(currentCapacity: 130, maxCapacity: 100, isACPowered: true)
        )

        XCTAssertEqual(status.value, "100%")
        XCTAssertEqual(status.chargeRatio, 1)
        XCTAssertEqual(status.state, .normal)
    }

    func testStatusItemMapping() {
        let item = SystemPowerProvider.status(
            from: makeReading(currentCapacity: 74, maxCapacity: 100, isACPowered: false)
        ).statusItem

        XCTAssertEqual(item.id, "power")
        XCTAssertEqual(item.providerID.rawValue, "system")
        XCTAssertEqual(item.title, "Power")
        XCTAssertEqual(item.value, "74%")
        XCTAssertEqual(item.subtitle, "On Battery")
        XCTAssertEqual(item.symbolName, "battery.100")
        XCTAssertEqual(item.state, .normal)
        XCTAssertEqual(item.sortPriority, 20)
    }

    private func makeReading(
        currentCapacity: Int,
        maxCapacity: Int,
        isCharging: Bool = false,
        isACPowered: Bool
    ) -> SystemPowerReading {
        SystemPowerReading(
            currentCapacity: currentCapacity,
            maxCapacity: maxCapacity,
            isCharging: isCharging,
            isACPowered: isACPowered,
            hasBattery: true
        )
    }
}
