import XCTest
@testable import Spill

@MainActor
final class SystemStatusStoreTests: XCTestCase {
    func testDefaultStoreStartsWithUnavailableStatuses() {
        let store = SystemStatusStore(
            cpuReader: { XCTFail("CPU reader should not run during initialization"); return .unavailableTestValue },
            memoryReader: { XCTFail("Memory reader should not run during initialization"); return .unavailableTestValue },
            storageReader: { XCTFail("Storage reader should not run during initialization"); return .unavailableTestValue },
            gpuReader: { XCTFail("GPU reader should not run during initialization"); return .unavailableTestValue },
            networkReader: { XCTFail("Network reader should not run during initialization"); return nil },
            powerReader: { XCTFail("Power reader should not run during initialization"); return .unavailableTestValue },
            networkInitialSampleIntervalNanoseconds: 0
        )

        XCTAssertEqual(store.cpu.state, .refreshing)
        XCTAssertEqual(store.cpu.value, "0.0%")
        XCTAssertEqual(store.cpu.subtitle, "Sampling")
        XCTAssertEqual(store.memory.state, .unavailable)
        XCTAssertEqual(store.memory.value, "N/A")
        XCTAssertEqual(store.storage.state, .unavailable)
        XCTAssertEqual(store.storage.value, "N/A")
        XCTAssertEqual(store.gpu.state, .unavailable)
        XCTAssertEqual(store.gpu.value, "N/A")
        XCTAssertEqual(store.network.state, .unavailable)
        XCTAssertEqual(store.network.value, "N/A")
        XCTAssertEqual(store.power.state, .unavailable)
        XCTAssertEqual(store.power.value, "N/A")
    }

    func testRefreshUsesInjectedReaders() async {
        let cpu = SystemCPUProvider.status(
            previous: SystemCPUReading(userTicks: 10, systemTicks: 10, idleTicks: 80, niceTicks: 0),
            current: SystemCPUReading(userTicks: 20, systemTicks: 20, idleTicks: 160, niceTicks: 0)
        )
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
        let network = SystemNetworkReading(
            receivedBytes: 1_000,
            sentBytes: 500,
            timestamp: 1,
            activeInterfaceCount: 1
        )
        let storage = SystemStorageProvider.status(
            from: SystemStorageReading(
                totalBytes: gib(100),
                availableBytes: gib(50)
            )
        )
        let gpu = SystemGPUProvider.status(
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
        )
        let store = SystemStatusStore(
            cpuReader: { cpu },
            memoryReader: { memory },
            storageReader: { storage },
            gpuReader: { gpu },
            networkReader: { network },
            powerReader: { power },
            networkInitialSampleIntervalNanoseconds: 0
        )

        await store.refresh(enabledModules: [.cpu, .memory, .storage, .gpu, .network])

        XCTAssertEqual(store.cpu.value, "20.0%")
        XCTAssertEqual(store.cpu.state, .normal)
        XCTAssertEqual(store.memory.value, "43.8%")
        XCTAssertEqual(store.memory.state, .normal)
        XCTAssertEqual(store.storage.value, "50.0%")
        XCTAssertEqual(store.storage.state, .normal)
        XCTAssertEqual(store.gpu.value, "1/1")
        XCTAssertEqual(store.gpu.state, .normal)
        XCTAssertEqual(store.network.value, "Sampling")
        XCTAssertEqual(store.network.state, .refreshing)
        XCTAssertEqual(store.power.value, "80%")
        XCTAssertEqual(store.power.subtitle, "On Battery")
    }

    func testRepeatedRefreshUpdatesCachedValues() async {
        var cpuReadCount = 0
        var memoryReadCount = 0
        var storageReadCount = 0
        var gpuReadCount = 0
        var networkReadCount = 0
        var powerReadCount = 0
        let store = SystemStatusStore(
            cpuReader: {
                cpuReadCount += 1
                return SystemCPUProvider.status(
                    previous: SystemCPUReading(userTicks: 0, systemTicks: 0, idleTicks: 0, niceTicks: 0),
                    current: SystemCPUReading(
                        userTicks: UInt64(cpuReadCount),
                        systemTicks: UInt64(cpuReadCount),
                        idleTicks: UInt64(8 * cpuReadCount),
                        niceTicks: 0
                    )
                )
            },
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
            storageReader: {
                storageReadCount += 1
                return SystemStorageProvider.status(
                    from: SystemStorageReading(
                        totalBytes: self.gib(10),
                        availableBytes: self.gib(UInt64(10 - storageReadCount))
                    )
                )
            },
            gpuReader: {
                gpuReadCount += 1
                return SystemGPUProvider.status(
                    from: [
                        SystemGPUDeviceStatus(
                            name: "GPU \(gpuReadCount)",
                            isLowPower: true,
                            isHeadless: false,
                            isRemovable: false,
                            hasUnifiedMemory: true,
                            recommendedMaxWorkingSetBytes: self.gib(UInt64(gpuReadCount))
                        )
                    ]
                )
            },
            networkReader: {
                networkReadCount += 1
                return SystemNetworkReading(
                    receivedBytes: UInt64(networkReadCount * 1_000),
                    sentBytes: UInt64(networkReadCount * 2_000),
                    timestamp: Double(networkReadCount),
                    activeInterfaceCount: 1
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
            },
            networkInitialSampleIntervalNanoseconds: 0
        )

        await store.refresh(enabledModules: [.cpu, .memory, .storage, .gpu, .network])
        XCTAssertEqual(store.cpu.value, "20.0%")
        XCTAssertEqual(store.memory.value, "10.0%")
        XCTAssertEqual(store.storage.value, "10.0%")
        XCTAssertEqual(store.gpu.subtitle, "1.0 GB recommended budget")
        XCTAssertEqual(store.network.value, "↓ 1.0 KB/s")
        XCTAssertEqual(store.network.subtitle, "↑ 2.0 KB/s")
        XCTAssertEqual(store.networkTrafficHistory.received.count, 1)
        XCTAssertEqual(store.networkTrafficHistory.sent.count, 1)
        XCTAssertEqual(store.networkTrafficHistory.received[0], 0.0001, accuracy: 0.000001)
        XCTAssertEqual(store.networkTrafficHistory.sent[0], 0.0002, accuracy: 0.000001)
        XCTAssertEqual(store.power.value, "51%")

        await store.refresh(enabledModules: [.cpu, .memory, .storage, .gpu, .network])
        XCTAssertEqual(store.cpu.value, "20.0%")
        XCTAssertEqual(store.memory.value, "20.0%")
        XCTAssertEqual(store.storage.value, "20.0%")
        XCTAssertEqual(store.gpu.subtitle, "2.0 GB recommended budget")
        XCTAssertEqual(store.network.value, "↓ 1.0 KB/s")
        XCTAssertEqual(store.network.subtitle, "↑ 2.0 KB/s")
        XCTAssertEqual(store.networkTrafficHistory.received.count, 2)
        XCTAssertEqual(store.networkTrafficHistory.sent.count, 2)
        XCTAssertEqual(store.networkTrafficHistory.received[1], 0.0001, accuracy: 0.000001)
        XCTAssertEqual(store.networkTrafficHistory.sent[1], 0.0002, accuracy: 0.000001)
        XCTAssertEqual(store.power.value, "52%")
    }

    func testDisabledModulesDoNotRunReaders() async {
        var cpuReadCount = 0
        var memoryReadCount = 0
        var storageReadCount = 0
        var gpuReadCount = 0
        var networkReadCount = 0
        var powerReadCount = 0
        let store = SystemStatusStore(
            cpuReader: {
                cpuReadCount += 1
                return .unavailableTestValue
            },
            memoryReader: {
                memoryReadCount += 1
                return .unavailableTestValue
            },
            storageReader: {
                storageReadCount += 1
                return .unavailableTestValue
            },
            gpuReader: {
                gpuReadCount += 1
                return .unavailableTestValue
            },
            networkReader: {
                networkReadCount += 1
                return nil
            },
            powerReader: {
                powerReadCount += 1
                return .unavailableTestValue
            },
            networkInitialSampleIntervalNanoseconds: 0
        )

        await store.refresh(enabledModules: [])

        XCTAssertEqual(cpuReadCount, 0)
        XCTAssertEqual(memoryReadCount, 0)
        XCTAssertEqual(storageReadCount, 0)
        XCTAssertEqual(gpuReadCount, 0)
        XCTAssertEqual(networkReadCount, 0)
        XCTAssertEqual(powerReadCount, 1)
        XCTAssertEqual(store.cpu.state, .unavailable)
        XCTAssertEqual(store.memory.state, .unavailable)
        XCTAssertEqual(store.storage.state, .unavailable)
        XCTAssertEqual(store.gpu.state, .unavailable)
        XCTAssertEqual(store.network.state, .unavailable)
    }

    func testHiddenPowerFooterDoesNotRunPowerReader() async {
        var powerReadCount = 0
        let store = SystemStatusStore(
            cpuReader: { .unavailableTestValue },
            memoryReader: { .unavailableTestValue },
            storageReader: { .unavailableTestValue },
            gpuReader: { .unavailableTestValue },
            networkReader: { nil },
            powerReader: {
                powerReadCount += 1
                return .unavailableTestValue
            },
            networkInitialSampleIntervalNanoseconds: 0
        )

        await store.refresh(readsPower: false)

        XCTAssertEqual(powerReadCount, 0)
        XCTAssertEqual(store.power.state, .unavailable)
    }

    private func gib(_ value: UInt64) -> UInt64 {
        value * 1_073_741_824
    }
}

private extension SystemMemoryStatus {
    static let unavailableTestValue = SystemMemoryProvider.status(from: nil)
}

private extension SystemStorageStatus {
    static let unavailableTestValue = SystemStorageProvider.status(from: nil)
}

private extension SystemPowerStatus {
    static let unavailableTestValue = SystemPowerProvider.status(from: nil)
}

private extension SystemNetworkStatus {
    static let unavailableTestValue = SystemNetworkProvider.status(previous: nil, current: nil)
}

private extension SystemGPUStatus {
    static let unavailableTestValue = SystemGPUProvider.status(from: nil)
}

private extension SystemCPUStatus {
    static let unavailableTestValue = SystemCPUProvider.status(previous: nil, current: nil)
}
