import XCTest
@testable import Spill

final class SystemGPUProviderTests: XCTestCase {
    func testGPUStatusMappingWithUsableDevice() {
        let status = SystemGPUProvider.status(
            from: [
                SystemGPUDeviceStatus(
                    name: "Apple M GPU",
                    isLowPower: true,
                    isHeadless: false,
                    isRemovable: false,
                    hasUnifiedMemory: true,
                    recommendedMaxWorkingSetBytes: gib(12)
                )
            ]
        )

        XCTAssertEqual(status.value, "1/1")
        XCTAssertEqual(status.subtitle, "12 GB recommended budget")
        XCTAssertEqual(status.availableDeviceCount, 1)
        XCTAssertEqual(status.totalDeviceCount, 1)
        XCTAssertEqual(status.totalRecommendedMaxWorkingSetBytes, gib(12))
        XCTAssertEqual(status.state, .normal)
        XCTAssertEqual(status.devices.first?.memoryLabel, "12 GB")
    }

    func testGPUStatusMappingWithHeadlessOnlyDeviceWarns() {
        let status = SystemGPUProvider.status(
            from: [
                SystemGPUDeviceStatus(
                    name: "Headless GPU",
                    isLowPower: false,
                    isHeadless: true,
                    isRemovable: false,
                    hasUnifiedMemory: false,
                    recommendedMaxWorkingSetBytes: 0
                )
            ]
        )

        XCTAssertEqual(status.value, "0/1")
        XCTAssertEqual(status.subtitle, "0 usable devices")
        XCTAssertEqual(status.state, .warning)
    }

    func testUnavailableGPUStatusWhenDevicesAreMissing() {
        let status = SystemGPUProvider.status(from: nil)

        XCTAssertEqual(status.value, "N/A")
        XCTAssertNil(status.subtitle)
        XCTAssertEqual(status.availableDeviceCount, 0)
        XCTAssertEqual(status.totalDeviceCount, 0)
        XCTAssertEqual(status.state, .unavailable)
        XCTAssertEqual(status.statusItem.state, .unavailable)
    }

    func testStatusItemMapping() {
        let item = SystemGPUProvider.status(
            from: [
                SystemGPUDeviceStatus(
                    name: "Apple GPU",
                    isLowPower: true,
                    isHeadless: false,
                    isRemovable: false,
                    hasUnifiedMemory: true,
                    recommendedMaxWorkingSetBytes: gib(8)
                )
            ]
        ).statusItem

        XCTAssertEqual(item.id, "gpu")
        XCTAssertEqual(item.providerID.rawValue, "system")
        XCTAssertEqual(item.title, "GPU")
        XCTAssertEqual(item.value, "1/1")
        XCTAssertEqual(item.subtitle, "8.0 GB recommended budget")
        XCTAssertEqual(item.symbolName, "display")
        XCTAssertEqual(item.state, .normal)
        XCTAssertEqual(item.sortPriority, 12)
    }

    private func gib(_ value: UInt64) -> UInt64 {
        value * 1_073_741_824
    }
}
