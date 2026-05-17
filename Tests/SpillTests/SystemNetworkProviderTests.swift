import XCTest
@testable import Spill

final class SystemNetworkProviderTests: XCTestCase {
    func testSamplingStatusWhenPreviousReadingIsMissing() {
        let status = SystemNetworkProvider.status(
            previous: nil,
            current: SystemNetworkReading(
                receivedBytes: 1_000,
                sentBytes: 500,
                timestamp: 10,
                activeInterfaceCount: 1
            )
        )

        XCTAssertEqual(status.value, "Sampling")
        XCTAssertEqual(status.subtitle, "Waiting for second sample")
        XCTAssertEqual(status.activityRatio, 0)
        XCTAssertEqual(status.receivedBytesPerSecond, 0)
        XCTAssertEqual(status.sentBytesPerSecond, 0)
        XCTAssertEqual(status.totalBytesPerSecond, 0)
        XCTAssertEqual(status.activeInterfaceCount, 1)
        XCTAssertEqual(status.state, .refreshing)
    }

    func testThroughputStatusMapping() {
        let status = SystemNetworkProvider.status(
            previous: SystemNetworkReading(
                receivedBytes: 1_000_000,
                sentBytes: 500_000,
                timestamp: 10,
                activeInterfaceCount: 1
            ),
            current: SystemNetworkReading(
                receivedBytes: 2_500_000,
                sentBytes: 1_100_000,
                timestamp: 11.5,
                activeInterfaceCount: 2
            )
        )

        XCTAssertEqual(status.value, "↓ 1.0 MB/s")
        XCTAssertEqual(status.subtitle, "↑ 400 KB/s")
        XCTAssertEqual(status.activityRatio, 0.14, accuracy: 0.001)
        XCTAssertEqual(status.receivedBytesPerSecond, 1_000_000, accuracy: 0.001)
        XCTAssertEqual(status.sentBytesPerSecond, 400_000, accuracy: 0.001)
        XCTAssertEqual(status.totalBytesPerSecond, 1_400_000, accuracy: 0.001)
        XCTAssertEqual(status.totalReceivedBytes, 2_500_000)
        XCTAssertEqual(status.totalSentBytes, 1_100_000)
        XCTAssertEqual(status.activeInterfaceCount, 2)
        XCTAssertEqual(status.sampleInterval, 1.5)
        XCTAssertEqual(status.state, .active)
    }

    func testIdleStatusMapping() {
        let status = SystemNetworkProvider.status(
            previous: SystemNetworkReading(
                receivedBytes: 1_000,
                sentBytes: 500,
                timestamp: 10,
                activeInterfaceCount: 1
            ),
            current: SystemNetworkReading(
                receivedBytes: 1_000,
                sentBytes: 500,
                timestamp: 11,
                activeInterfaceCount: 1
            )
        )

        XCTAssertEqual(status.value, "↓ 0 B/s")
        XCTAssertEqual(status.subtitle, "↑ 0 B/s")
        XCTAssertEqual(status.activityRatio, 0)
        XCTAssertEqual(status.state, .normal)
    }

    func testCounterResetUsesCurrentBytesAsDelta() {
        let status = SystemNetworkProvider.status(
            previous: SystemNetworkReading(
                receivedBytes: 10_000,
                sentBytes: 10_000,
                timestamp: 10,
                activeInterfaceCount: 1
            ),
            current: SystemNetworkReading(
                receivedBytes: 1_500,
                sentBytes: 500,
                timestamp: 11,
                activeInterfaceCount: 1
            )
        )

        XCTAssertEqual(status.value, "↓ 1.5 KB/s")
        XCTAssertEqual(status.subtitle, "↑ 500 B/s")
    }

    func testUnavailableNetworkStatusWhenReadingIsMissing() {
        let status = SystemNetworkProvider.status(previous: nil, current: nil)

        XCTAssertEqual(status.value, "N/A")
        XCTAssertNil(status.subtitle)
        XCTAssertEqual(status.activityRatio, 0)
        XCTAssertEqual(status.state, .unavailable)
        XCTAssertEqual(status.statusItem.state, .unavailable)
    }

    func testStatusItemMapping() {
        let item = SystemNetworkProvider.status(
            previous: SystemNetworkReading(
                receivedBytes: 0,
                sentBytes: 0,
                timestamp: 10,
                activeInterfaceCount: 1
            ),
            current: SystemNetworkReading(
                receivedBytes: 1_000,
                sentBytes: 500,
                timestamp: 11,
                activeInterfaceCount: 1
            )
        ).statusItem

        XCTAssertEqual(item.id, "network")
        XCTAssertEqual(item.providerID.rawValue, "system")
        XCTAssertEqual(item.title, "Network")
        XCTAssertEqual(item.value, "↓ 1.0 KB/s")
        XCTAssertEqual(item.subtitle, "↑ 500 B/s")
        XCTAssertEqual(item.symbolName, "network")
        XCTAssertEqual(item.state, .active)
        XCTAssertEqual(item.sortPriority, 15)
    }

    func testNetworkByteFormatting() {
        XCTAssertEqual(SystemNetworkProvider.formatBytes(999), "999 B")
        XCTAssertEqual(SystemNetworkProvider.formatBytes(1_500), "1.5 KB")
        XCTAssertEqual(SystemNetworkProvider.formatBytes(10_000), "10 KB")
        XCTAssertEqual(SystemNetworkProvider.formatBytes(1_500_000), "1.5 MB")
    }
}
