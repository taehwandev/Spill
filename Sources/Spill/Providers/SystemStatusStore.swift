import SwiftUI

@MainActor
final class SystemStatusStore: ObservableObject {
    typealias CPUReader = () async -> SystemCPUStatus
    typealias MemoryReader = () -> SystemMemoryStatus
    typealias StorageReader = () -> SystemStorageStatus
    typealias GPUReader = () -> SystemGPUStatus
    typealias NetworkReader = () -> SystemNetworkReading?
    typealias PowerReader = () -> SystemPowerStatus

    @Published private(set) var cpu: SystemCPUStatus
    @Published private(set) var memory: SystemMemoryStatus
    @Published private(set) var storage: SystemStorageStatus
    @Published private(set) var gpu: SystemGPUStatus
    @Published private(set) var network: SystemNetworkStatus
    @Published private(set) var power: SystemPowerStatus
    @Published private(set) var metricHistory: [SpillStatusModule: [Double]]
    @Published private(set) var networkTrafficHistory: SystemNetworkTrafficHistory

    private let cpuReader: CPUReader
    private let memoryReader: MemoryReader
    private let storageReader: StorageReader
    private let gpuReader: GPUReader
    private let networkReader: NetworkReader
    private let powerReader: PowerReader
    private let maximumHistoryCount = 24
    private let networkInitialSampleIntervalNanoseconds: UInt64
    private var previousNetworkReading: SystemNetworkReading?

    init(
        cpu: SystemCPUStatus = SystemCPUProvider.status(previous: nil, current: nil),
        memory: SystemMemoryStatus = SystemMemoryProvider.status(from: nil),
        storage: SystemStorageStatus = SystemStorageProvider.status(from: nil),
        gpu: SystemGPUStatus = SystemGPUProvider.status(from: nil),
        network: SystemNetworkStatus = SystemNetworkProvider.status(previous: nil, current: nil),
        power: SystemPowerStatus = SystemPowerProvider.status(from: nil),
        cpuReader: @escaping CPUReader = { await SystemCPUProvider.status() },
        memoryReader: @escaping MemoryReader = { SystemMemoryProvider.status() },
        storageReader: @escaping StorageReader = { SystemStorageProvider.status() },
        gpuReader: @escaping GPUReader = { SystemGPUProvider.status() },
        networkReader: @escaping NetworkReader = { SystemNetworkProvider.currentReading() },
        powerReader: @escaping PowerReader = { SystemPowerProvider.status() },
        networkInitialSampleIntervalNanoseconds: UInt64 = 250_000_000
    ) {
        self.cpu = cpu
        self.memory = memory
        self.storage = storage
        self.gpu = gpu
        self.network = network
        self.power = power
        metricHistory = [
            .cpu: Self.initialHistory(for: cpu.usageRatio, state: cpu.state),
            .memory: Self.initialHistory(for: memory.usageRatio, state: memory.state),
            .storage: Self.initialHistory(for: storage.usageRatio, state: storage.state),
            .network: Self.initialHistory(for: network.activityRatio, state: network.state)
        ]
        networkTrafficHistory = SystemNetworkTrafficHistory(
            received: Self.initialHistory(for: network.receivedActivityRatio, state: network.state),
            sent: Self.initialHistory(for: network.sentActivityRatio, state: network.state)
        )
        self.cpuReader = cpuReader
        self.memoryReader = memoryReader
        self.storageReader = storageReader
        self.gpuReader = gpuReader
        self.networkReader = networkReader
        self.powerReader = powerReader
        self.networkInitialSampleIntervalNanoseconds = networkInitialSampleIntervalNanoseconds
    }

    func refresh(
        enabledModules: Set<SpillStatusModule> = SpillStatusModule.defaultEnabled,
        readsPower: Bool = true
    ) async {
        if enabledModules.contains(.memory) {
            memory = memoryReader()
            appendHistory(memory.usageRatio, for: .memory, state: memory.state)
        } else {
            memory = SystemMemoryProvider.status(from: nil)
        }

        if enabledModules.contains(.storage) {
            storage = storageReader()
            appendHistory(storage.usageRatio, for: .storage, state: storage.state)
        } else {
            storage = SystemStorageProvider.status(from: nil)
        }

        if enabledModules.contains(.network) {
            let previousReading = await networkPreviousReadingForRefresh()
            let currentNetworkReading = networkReader()
            network = SystemNetworkProvider.status(previous: previousReading, current: currentNetworkReading)
            if let currentNetworkReading {
                previousNetworkReading = currentNetworkReading
            }
            appendHistory(network.activityRatio, for: .network, state: network.state)
            appendNetworkTrafficHistory(network)
        } else {
            network = SystemNetworkProvider.status(previous: nil, current: nil)
            previousNetworkReading = nil
        }

        if enabledModules.contains(.gpu) {
            gpu = gpuReader()
        } else {
            gpu = SystemGPUProvider.status(from: nil)
        }

        if readsPower {
            power = powerReader()
        } else {
            power = SystemPowerProvider.status(from: nil)
        }

        if enabledModules.contains(.cpu) {
            cpu = await cpuReader()
            appendHistory(cpu.usageRatio, for: .cpu, state: cpu.state)
        } else {
            cpu = SystemCPUProvider.unavailableStatus()
        }
    }

    func history(for module: SpillStatusModule) -> [Double] {
        metricHistory[module] ?? []
    }

    private func appendHistory(_ value: Double, for module: SpillStatusModule, state: SpillStatusState) {
        guard state != .unavailable, value.isFinite else {
            return
        }

        var values = metricHistory[module] ?? []
        values.append(value.clamped(to: 0...1))
        if values.count > maximumHistoryCount {
            values.removeFirst(values.count - maximumHistoryCount)
        }
        metricHistory[module] = values
    }

    private func appendNetworkTrafficHistory(_ status: SystemNetworkStatus) {
        guard status.state != .unavailable else {
            return
        }

        networkTrafficHistory = SystemNetworkTrafficHistory(
            received: appendedHistoryValue(status.receivedActivityRatio, to: networkTrafficHistory.received),
            sent: appendedHistoryValue(status.sentActivityRatio, to: networkTrafficHistory.sent)
        )
    }

    private func appendedHistoryValue(_ value: Double, to history: [Double]) -> [Double] {
        guard value.isFinite else {
            return history
        }

        var values = history
        values.append(value.clamped(to: 0...1))
        if values.count > maximumHistoryCount {
            values.removeFirst(values.count - maximumHistoryCount)
        }
        return values
    }

    private static func initialHistory(for value: Double, state: SpillStatusState) -> [Double] {
        guard state != .unavailable, value.isFinite else {
            return []
        }

        return [value.clamped(to: 0...1)]
    }

    private func networkPreviousReadingForRefresh() async -> SystemNetworkReading? {
        if let previousNetworkReading {
            return previousNetworkReading
        }

        let initialReading = networkReader()
        guard initialReading != nil else {
            return nil
        }

        if networkInitialSampleIntervalNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: networkInitialSampleIntervalNanoseconds)
        }
        return initialReading
    }
}

struct SystemNetworkTrafficHistory: Equatable, Sendable {
    let received: [Double]
    let sent: [Double]
}
