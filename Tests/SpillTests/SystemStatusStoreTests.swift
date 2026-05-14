import XCTest
@testable import Spill

@MainActor
final class SystemStatusStoreTests: XCTestCase {
    func testDefaultStoreStartsWithUnavailableStatuses() {
        let store = SystemStatusStore(
            memoryReader: { XCTFail("Memory reader should not run during initialization"); return .unavailableTestValue },
            powerReader: { XCTFail("Power reader should not run during initialization"); return .unavailableTestValue }
        )

        XCTAssertEqual(store.memory.state, .unavailable)
        XCTAssertEqual(store.memory.value, "N/A")
        XCTAssertEqual(store.power.state, .unavailable)
        XCTAssertEqual(store.power.value, "N/A")
    }

    func testRefreshUsesInjectedReaders() {
        let memory = SystemMemoryProvider.status(
            from: SystemMemoryReading(
                totalBytes: gib(16),
                freeBytes: gib(2),
                activeBytes: gib(4),
                inactiveBytes: gib(1),
                wiredBytes: gib(2),
                compressedBytes: gib(1)
            )
        )
        let power = SystemPowerProvider.status(
            from: SystemPowerReading(
                currentCapacity: 80,
                maxCapacity: 100,
                isCharging: false,
                isACPowered: false,
                hasBattery: true
            )
        )
        let store = SystemStatusStore(memoryReader: { memory }, powerReader: { power })

        store.refresh()

        XCTAssertEqual(store.memory.value, "44%")
        XCTAssertEqual(store.memory.state, .normal)
        XCTAssertEqual(store.power.value, "80%")
        XCTAssertEqual(store.power.subtitle, "On Battery")
    }

    func testRepeatedRefreshUpdatesCachedValues() {
        var memoryReadCount = 0
        var powerReadCount = 0
        let store = SystemStatusStore(
            memoryReader: {
                memoryReadCount += 1
                return SystemMemoryProvider.status(
                    from: SystemMemoryReading(
                        totalBytes: self.gib(10),
                        freeBytes: 0,
                        activeBytes: self.gib(UInt64(memoryReadCount)),
                        inactiveBytes: 0,
                        wiredBytes: 0,
                        compressedBytes: 0
                    )
                )
            },
            powerReader: {
                powerReadCount += 1
                return SystemPowerProvider.status(
                    from: SystemPowerReading(
                        currentCapacity: 50 + powerReadCount,
                        maxCapacity: 100,
                        isCharging: false,
                        isACPowered: false,
                        hasBattery: true
                    )
                )
            }
        )

        store.refresh()
        XCTAssertEqual(store.memory.value, "10%")
        XCTAssertEqual(store.power.value, "51%")

        store.refresh()
        XCTAssertEqual(store.memory.value, "20%")
        XCTAssertEqual(store.power.value, "52%")
    }

    private func gib(_ value: UInt64) -> UInt64 {
        value * 1_073_741_824
    }
}

private extension SystemMemoryStatus {
    static let unavailableTestValue = SystemMemoryProvider.status(from: nil)
}

private extension SystemPowerStatus {
    static let unavailableTestValue = SystemPowerProvider.status(from: nil)
}
