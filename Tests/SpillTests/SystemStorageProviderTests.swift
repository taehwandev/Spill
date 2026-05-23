import XCTest
@testable import Spill

final class SystemStorageProviderTests: XCTestCase {
    func testNormalStorageStatusMapping() {
        let status = SystemStorageProvider.status(
            from: SystemStorageReading(
                totalBytes: gib(100),
                availableBytes: gib(45)
            )
        )

        XCTAssertEqual(status.value, "55.0%")
        XCTAssertEqual(status.subtitle, "45 GB available of 100 GB")
        XCTAssertEqual(status.usedBytes, gib(55))
        XCTAssertEqual(status.availableBytes, gib(45))
        XCTAssertEqual(status.totalBytes, gib(100))
        XCTAssertEqual(status.state, .normal)
        XCTAssertEqual(status.usageRatio, 0.55, accuracy: 0.0001)
    }

    func testActiveAndWarningStorageThresholds() {
        let active = SystemStorageProvider.status(
            from: SystemStorageReading(totalBytes: gib(100), availableBytes: gib(20))
        )
        let warning = SystemStorageProvider.status(
            from: SystemStorageReading(totalBytes: gib(100), availableBytes: gib(8))
        )

        XCTAssertEqual(active.value, "80.0%")
        XCTAssertEqual(active.state, .active)
        XCTAssertEqual(warning.value, "92.0%")
        XCTAssertEqual(warning.state, .warning)
    }

    func testStorageStatusClampsInvalidAvailableCapacity() {
        let status = SystemStorageProvider.status(
            from: SystemStorageReading(
                totalBytes: gib(10),
                availableBytes: gib(12)
            )
        )

        XCTAssertEqual(status.value, "0.0%")
        XCTAssertEqual(status.subtitle, "10 GB available of 10 GB")
        XCTAssertEqual(status.usedBytes, 0)
        XCTAssertEqual(status.availableBytes, gib(10))
        XCTAssertEqual(status.usageRatio, 0)
        XCTAssertEqual(status.state, .normal)
    }

    func testUnavailableStorageStatusWhenReadingIsMissing() {
        let status = SystemStorageProvider.status(from: nil)

        XCTAssertEqual(status.value, "N/A")
        XCTAssertNil(status.subtitle)
        XCTAssertEqual(status.usageRatio, 0)
        XCTAssertEqual(status.state, .unavailable)
        XCTAssertEqual(status.statusItem.state, .unavailable)
    }

    func testStatusItemMapping() {
        let item = SystemStorageProvider.status(
            from: SystemStorageReading(
                totalBytes: gib(100),
                availableBytes: gib(45)
            )
        ).statusItem

        XCTAssertEqual(item.id, "storage")
        XCTAssertEqual(item.providerID.rawValue, "system")
        XCTAssertEqual(item.title, "Storage")
        XCTAssertEqual(item.value, "55.0%")
        XCTAssertEqual(item.subtitle, "45 GB available of 100 GB")
        XCTAssertEqual(item.symbolName, "internaldrive")
    }

    private func gib(_ value: UInt64) -> UInt64 {
        value * 1_073_741_824
    }
}
