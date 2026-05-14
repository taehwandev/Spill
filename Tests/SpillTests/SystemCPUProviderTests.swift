import XCTest
@testable import Spill

final class SystemCPUProviderTests: XCTestCase {
    func testNormalCPUStatusMapping() {
        let status = SystemCPUProvider.status(
            previous: makeReading(active: 100, idle: 300),
            current: makeReading(active: 125, idle: 375)
        )

        XCTAssertEqual(status.value, "25%")
        XCTAssertEqual(status.subtitle, "Active")
        XCTAssertEqual(status.usageRatio, 0.25, accuracy: 0.0001)
        XCTAssertEqual(status.activeTicks, 25)
        XCTAssertEqual(status.totalTicks, 100)
        XCTAssertEqual(status.state, .normal)
    }

    func testActiveCPUStatusMapping() {
        let status = SystemCPUProvider.status(
            previous: makeReading(active: 100, idle: 300),
            current: makeReading(active: 170, idle: 330)
        )

        XCTAssertEqual(status.value, "70%")
        XCTAssertEqual(status.usageRatio, 0.7, accuracy: 0.0001)
        XCTAssertEqual(status.state, .active)
    }

    func testHighCPUStatusMapping() {
        let status = SystemCPUProvider.status(
            previous: makeReading(active: 100, idle: 300),
            current: makeReading(active: 195, idle: 305)
        )

        XCTAssertEqual(status.value, "95%")
        XCTAssertEqual(status.usageRatio, 0.95, accuracy: 0.0001)
        XCTAssertEqual(status.state, .warning)
    }

    func testCPUStatusClampsUsageRatio() {
        let status = SystemCPUProvider.status(
            previous: SystemCPUReading(userTicks: 100, systemTicks: 0, idleTicks: 100, niceTicks: 0),
            current: SystemCPUReading(userTicks: 250, systemTicks: 0, idleTicks: 100, niceTicks: 0)
        )

        XCTAssertEqual(status.value, "100%")
        XCTAssertEqual(status.usageRatio, 1)
        XCTAssertEqual(status.state, .warning)
    }

    func testUnavailableCPUStatusWhenReadingsAreMissing() {
        let status = SystemCPUProvider.status(previous: nil, current: makeReading(active: 1, idle: 1))

        XCTAssertEqual(status.value, "N/A")
        XCTAssertNil(status.subtitle)
        XCTAssertEqual(status.usageRatio, 0)
        XCTAssertEqual(status.state, .unavailable)
        XCTAssertEqual(status.statusItem.state, .unavailable)
    }

    func testUnavailableCPUStatusWhenTotalDeltaIsZero() {
        let reading = makeReading(active: 100, idle: 300)
        let status = SystemCPUProvider.status(previous: reading, current: reading)

        XCTAssertEqual(status.value, "N/A")
        XCTAssertEqual(status.state, .unavailable)
    }

    func testUnavailableCPUStatusWhenCountersMoveBackward() {
        let status = SystemCPUProvider.status(
            previous: makeReading(active: 100, idle: 300),
            current: makeReading(active: 90, idle: 310)
        )

        XCTAssertEqual(status.value, "N/A")
        XCTAssertEqual(status.state, .unavailable)
    }

    func testStatusItemMapping() {
        let item = SystemCPUProvider.status(
            previous: makeReading(active: 100, idle: 300),
            current: makeReading(active: 125, idle: 375)
        ).statusItem

        XCTAssertEqual(item.id, "cpu")
        XCTAssertEqual(item.providerID.rawValue, "system")
        XCTAssertEqual(item.title, "CPU")
        XCTAssertEqual(item.value, "25%")
        XCTAssertEqual(item.subtitle, "Active")
        XCTAssertEqual(item.symbolName, "cpu")
        XCTAssertEqual(item.state, .normal)
        XCTAssertEqual(item.sortPriority, 5)
    }

    private func makeReading(active: UInt64, idle: UInt64) -> SystemCPUReading {
        SystemCPUReading(
            userTicks: active,
            systemTicks: 0,
            idleTicks: idle,
            niceTicks: 0
        )
    }
}
