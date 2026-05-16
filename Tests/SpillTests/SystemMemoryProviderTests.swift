import XCTest
@testable import Spill

final class SystemMemoryProviderTests: XCTestCase {
    func testNormalMemoryStatusMapping() {
        let reading = makeReading(
            totalBytes: gib(16),
            activeBytes: gib(4),
            wiredBytes: gib(2),
            compressedBytes: gib(1)
        )

        let status = SystemMemoryProvider.status(from: reading)

        XCTAssertEqual(status.value, "43.8%")
        XCTAssertEqual(status.subtitle, "3.0 GB available of 16 GB")
        XCTAssertEqual(status.usedBytes, gib(7))
        XCTAssertEqual(status.availableBytes, gib(3))
        XCTAssertEqual(status.freeBytes, gib(2))
        XCTAssertEqual(status.activeBytes, gib(4))
        XCTAssertEqual(status.inactiveBytes, gib(1))
        XCTAssertEqual(status.wiredBytes, gib(2))
        XCTAssertEqual(status.compressedBytes, gib(1))
        XCTAssertEqual(status.totalBytes, gib(16))
        XCTAssertEqual(status.state, .normal)
        XCTAssertEqual(status.usageRatio, 0.4375, accuracy: 0.0001)
    }

    func testElevatedMemoryStatusMapping() {
        let reading = makeReading(
            totalBytes: gib(16),
            activeBytes: gib(7),
            wiredBytes: gib(3),
            compressedBytes: gib(2)
        )

        let status = SystemMemoryProvider.status(from: reading)

        XCTAssertEqual(status.value, "75.0%")
        XCTAssertEqual(status.state, .active)
        XCTAssertEqual(status.usageRatio, 0.75, accuracy: 0.0001)
    }

    func testHighMemoryStatusMapping() {
        let reading = makeReading(
            totalBytes: gib(16),
            activeBytes: gib(8),
            wiredBytes: gib(4),
            compressedBytes: gib(3)
        )

        let status = SystemMemoryProvider.status(from: reading)

        XCTAssertEqual(status.value, "93.8%")
        XCTAssertEqual(status.state, .warning)
        XCTAssertEqual(status.usageRatio, 0.9375, accuracy: 0.0001)
    }

    func testMemoryStatusClampsUsageRatio() {
        let reading = makeReading(
            totalBytes: gib(8),
            activeBytes: gib(8),
            wiredBytes: gib(2),
            compressedBytes: gib(1)
        )

        let status = SystemMemoryProvider.status(from: reading)

        XCTAssertEqual(status.value, "100.0%")
        XCTAssertEqual(status.usageRatio, 1)
        XCTAssertEqual(status.state, .warning)
    }

    func testUnavailableMemoryStatusWhenReadingIsMissing() {
        let status = SystemMemoryProvider.status(from: nil)

        XCTAssertEqual(status.value, "N/A")
        XCTAssertNil(status.subtitle)
        XCTAssertEqual(status.usageRatio, 0)
        XCTAssertEqual(status.state, .unavailable)
        XCTAssertEqual(status.statusItem.state, .unavailable)
    }

    func testStatusItemMapping() {
        let reading = makeReading(
            totalBytes: gib(16),
            activeBytes: gib(4),
            wiredBytes: gib(2),
            compressedBytes: gib(1)
        )

        let item = SystemMemoryProvider.status(from: reading).statusItem

        XCTAssertEqual(item.id, "memory")
        XCTAssertEqual(item.providerID.rawValue, "system")
        XCTAssertEqual(item.title, "Memory")
        XCTAssertEqual(item.value, "43.8%")
        XCTAssertEqual(item.subtitle, "3.0 GB available of 16 GB")
        XCTAssertEqual(item.symbolName, "memorychip")
    }

    func testByteFormatting() {
        XCTAssertEqual(SystemMemoryProvider.formatBytes(gib(1) / 2), "0.5 GB")
        XCTAssertEqual(SystemMemoryProvider.formatBytes(gib(8)), "8.0 GB")
        XCTAssertEqual(SystemMemoryProvider.formatBytes(gib(16)), "16 GB")
    }

    private func makeReading(
        totalBytes: UInt64,
        freeBytes: UInt64 = 2 * 1_073_741_824,
        activeBytes: UInt64,
        inactiveBytes: UInt64 = 1 * 1_073_741_824,
        wiredBytes: UInt64,
        compressedBytes: UInt64
    ) -> SystemMemoryReading {
        SystemMemoryReading(
            totalBytes: totalBytes,
            freeBytes: freeBytes,
            activeBytes: activeBytes,
            inactiveBytes: inactiveBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes
        )
    }

    private func gib(_ value: UInt64) -> UInt64 {
        value * 1_073_741_824
    }
}
