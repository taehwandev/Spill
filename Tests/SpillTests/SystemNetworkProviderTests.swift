import XCTest
@testable import Spill

final class SystemNetworkProviderTests: XCTestCase {
    func testOnlineStatusMapping() {
        let status = SystemNetworkProvider.status(
            from: SystemNetworkReading(
                isReachable: true,
                connectionRequired: false,
                canConnectAutomatically: false,
                interventionRequired: false
            )
        )

        XCTAssertEqual(status.value, "Online")
        XCTAssertEqual(status.subtitle, "Default Route")
        XCTAssertEqual(status.availabilityRatio, 1)
        XCTAssertEqual(status.state, .normal)
        XCTAssertTrue(status.isAvailable)
        XCTAssertTrue(status.isReachable)
        XCTAssertFalse(status.connectionRequired)
        XCTAssertFalse(status.canConnectAutomatically)
        XCTAssertFalse(status.interventionRequired)
    }

    func testAutomaticConnectionStatusMapping() {
        let status = SystemNetworkProvider.status(
            from: SystemNetworkReading(
                isReachable: true,
                connectionRequired: true,
                canConnectAutomatically: true,
                interventionRequired: false
            )
        )

        XCTAssertEqual(status.value, "Online")
        XCTAssertEqual(status.state, .normal)
        XCTAssertTrue(status.isAvailable)
    }

    func testConnectionRequiredStatusMapping() {
        let status = SystemNetworkProvider.status(
            from: SystemNetworkReading(
                isReachable: true,
                connectionRequired: true,
                canConnectAutomatically: false,
                interventionRequired: false
            )
        )

        XCTAssertEqual(status.value, "Standby")
        XCTAssertEqual(status.subtitle, "Connection Required")
        XCTAssertEqual(status.availabilityRatio, 0.5)
        XCTAssertEqual(status.state, .active)
        XCTAssertFalse(status.isAvailable)
        XCTAssertTrue(status.isReachable)
        XCTAssertTrue(status.connectionRequired)
        XCTAssertFalse(status.canConnectAutomatically)
        XCTAssertFalse(status.interventionRequired)
    }

    func testOfflineStatusMapping() {
        let status = SystemNetworkProvider.status(
            from: SystemNetworkReading(
                isReachable: false,
                connectionRequired: false,
                canConnectAutomatically: false,
                interventionRequired: false
            )
        )

        XCTAssertEqual(status.value, "Offline")
        XCTAssertEqual(status.subtitle, "No Route")
        XCTAssertEqual(status.availabilityRatio, 0)
        XCTAssertEqual(status.state, .warning)
        XCTAssertFalse(status.isAvailable)
    }

    func testUnavailableNetworkStatusWhenReadingIsMissing() {
        let status = SystemNetworkProvider.status(from: nil)

        XCTAssertEqual(status.value, "N/A")
        XCTAssertNil(status.subtitle)
        XCTAssertEqual(status.availabilityRatio, 0)
        XCTAssertEqual(status.state, .unavailable)
        XCTAssertFalse(status.isAvailable)
        XCTAssertEqual(status.statusItem.state, .unavailable)
    }

    func testStatusItemMapping() {
        let item = SystemNetworkProvider.status(
            from: SystemNetworkReading(
                isReachable: true,
                connectionRequired: false,
                canConnectAutomatically: false,
                interventionRequired: false
            )
        ).statusItem

        XCTAssertEqual(item.id, "network")
        XCTAssertEqual(item.providerID.rawValue, "system")
        XCTAssertEqual(item.title, "Network")
        XCTAssertEqual(item.value, "Online")
        XCTAssertEqual(item.subtitle, "Default Route")
        XCTAssertEqual(item.symbolName, "network")
        XCTAssertEqual(item.state, .normal)
        XCTAssertEqual(item.sortPriority, 15)
    }
}
