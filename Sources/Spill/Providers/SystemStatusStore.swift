import SwiftUI

private struct SystemStatusSnapshot {
    var cpu: SystemCPUStatus
    var memory: SystemMemoryStatus
    var storage: SystemStorageStatus
    var gpu: SystemGPUStatus
    var network: SystemNetworkStatus
    var power: SystemPowerStatus
    var metricHistory: [SpillStatusModule: [Double]]
    var networkTrafficHistory: SystemNetworkTrafficHistory
    var cpuCoreHistory: [[Double]]
}

@MainActor
final class SystemStatusStore: ObservableObject {
    typealias CPUReader = () -> SystemCPUReading?
    typealias MemoryReader = () -> SystemMemoryStatus
    typealias StorageReader = () -> SystemStorageStatus
    typealias GPUReader = () -> SystemGPUStatus
    typealias NetworkReader = () -> SystemNetworkReading?
    typealias PowerReader = () -> SystemPowerStatus

    @Published private var snapshot: SystemStatusSnapshot

    var cpu: SystemCPUStatus { snapshot.cpu }
    var memory: SystemMemoryStatus { snapshot.memory }
    var storage: SystemStorageStatus { snapshot.storage }
    var gpu: SystemGPUStatus { snapshot.gpu }
    var network: SystemNetworkStatus { snapshot.network }
    var power: SystemPowerStatus { snapshot.power }
    var metricHistory: [SpillStatusModule: [Double]] { snapshot.metricHistory }
    var networkTrafficHistory: SystemNetworkTrafficHistory { snapshot.networkTrafficHistory }
    var cpuCoreHistory: [[Double]] { snapshot.cpuCoreHistory }

    private let cpuReader: CPUReader
    private let memoryReader: MemoryReader
    private let storageReader: StorageReader
    private let gpuReader: GPUReader
    private let networkReader: NetworkReader
    private let powerReader: PowerReader
    private let maximumHistoryCount = 24
    private let cpuInitialSampleIntervalNanoseconds: UInt64
    private let networkInitialSampleIntervalNanoseconds: UInt64
    private var previousCPUReading: SystemCPUReading?
    private var previousNetworkReading: SystemNetworkReading?

    init(
        cpu: SystemCPUStatus = SystemCPUProvider.status(previous: nil, current: nil),
        memory: SystemMemoryStatus = SystemMemoryProvider.status(from: nil),
        storage: SystemStorageStatus = SystemStorageProvider.status(from: nil),
        gpu: SystemGPUStatus = SystemGPUProvider.status(from: nil),
        network: SystemNetworkStatus = SystemNetworkProvider.status(previous: nil, current: nil),
        power: SystemPowerStatus = SystemPowerProvider.status(from: nil),
        previousCPUReading: SystemCPUReading? = nil,
        cpuReader: @escaping CPUReader = { SystemCPUProvider.currentReading() },
        memoryReader: @escaping MemoryReader = { SystemMemoryProvider.status() },
        storageReader: @escaping StorageReader = { SystemStorageProvider.status() },
        gpuReader: @escaping GPUReader = { SystemGPUProvider.status() },
        networkReader: @escaping NetworkReader = { SystemNetworkProvider.currentReading() },
        powerReader: @escaping PowerReader = { SystemPowerProvider.status() },
        cpuInitialSampleIntervalNanoseconds: UInt64 = 0,
        networkInitialSampleIntervalNanoseconds: UInt64 = 250_000_000
    ) {
        self.previousCPUReading = previousCPUReading
        snapshot = SystemStatusSnapshot(
            cpu: cpu,
            memory: memory,
            storage: storage,
            gpu: gpu,
            network: network,
            power: power,
            metricHistory: [
                .cpu: Self.initialHistory(for: cpu.usageRatio, state: cpu.state),
                .memory: Self.initialHistory(for: memory.usageRatio, state: memory.state),
                .storage: Self.initialHistory(for: storage.usageRatio, state: storage.state),
                .network: Self.initialHistory(for: network.activityRatio, state: network.state)
            ],
            networkTrafficHistory: SystemNetworkTrafficHistory(
                received: Self.initialHistory(for: network.receivedActivityRatio, state: network.state),
                sent: Self.initialHistory(for: network.sentActivityRatio, state: network.state)
            ),
            cpuCoreHistory: Self.initialCoreHistory(for: cpu.coreUsageRatios, state: cpu.state)
        )
        self.cpuReader = cpuReader
        self.memoryReader = memoryReader
        self.storageReader = storageReader
        self.gpuReader = gpuReader
        self.networkReader = networkReader
        self.powerReader = powerReader
        self.cpuInitialSampleIntervalNanoseconds = cpuInitialSampleIntervalNanoseconds
        self.networkInitialSampleIntervalNanoseconds = networkInitialSampleIntervalNanoseconds
    }
}

extension SystemStatusStore {
    func refresh(
        enabledModules: Set<SpillStatusModule> = SpillStatusModule.defaultEnabled,
        readsPower: Bool = true
    ) async {
        var nextSnapshot = snapshot

        if enabledModules.contains(.memory) {
            nextSnapshot.memory = memoryReader()
            appendHistory(
                nextSnapshot.memory.usageRatio,
                for: .memory,
                state: nextSnapshot.memory.state,
                to: &nextSnapshot
            )
        } else {
            nextSnapshot.memory = SystemMemoryProvider.status(from: nil)
        }

        if enabledModules.contains(.storage) {
            nextSnapshot.storage = storageReader()
            appendHistory(
                nextSnapshot.storage.usageRatio,
                for: .storage,
                state: nextSnapshot.storage.state,
                to: &nextSnapshot
            )
        } else {
            nextSnapshot.storage = SystemStorageProvider.status(from: nil)
        }

        if enabledModules.contains(.network) {
            let previousReading = await networkPreviousReadingForRefresh()
            let currentNetworkReading = networkReader()
            nextSnapshot.network = SystemNetworkProvider.status(
                previous: previousReading,
                current: currentNetworkReading
            )
            if let currentNetworkReading {
                previousNetworkReading = currentNetworkReading
            }
            appendHistory(
                nextSnapshot.network.activityRatio,
                for: .network,
                state: nextSnapshot.network.state,
                to: &nextSnapshot
            )
            appendNetworkTrafficHistory(nextSnapshot.network, to: &nextSnapshot)
        } else {
            nextSnapshot.network = SystemNetworkProvider.status(previous: nil, current: nil)
            previousNetworkReading = nil
        }

        if enabledModules.contains(.gpu) {
            nextSnapshot.gpu = gpuReader()
        } else {
            nextSnapshot.gpu = SystemGPUProvider.status(from: nil)
        }

        if readsPower {
            nextSnapshot.power = powerReader()
        } else {
            nextSnapshot.power = SystemPowerProvider.status(from: nil)
        }

        if enabledModules.contains(.cpu) {
            let previousReading = await cpuPreviousReadingForRefresh()
            let currentCPUReading = cpuReader()
            nextSnapshot.cpu = SystemCPUProvider.status(
                previous: previousReading,
                current: currentCPUReading
            )
            if let currentCPUReading {
                previousCPUReading = currentCPUReading
            }
            appendHistory(
                nextSnapshot.cpu.usageRatio,
                for: .cpu,
                state: nextSnapshot.cpu.state,
                to: &nextSnapshot
            )
            appendCPUCoreHistory(nextSnapshot.cpu, to: &nextSnapshot)
        } else {
            nextSnapshot.cpu = SystemCPUProvider.unavailableStatus()
            previousCPUReading = nil
            nextSnapshot.cpuCoreHistory = []
        }

        snapshot = nextSnapshot
    }

    private func cpuPreviousReadingForRefresh() async -> SystemCPUReading? {
        if let previousCPUReading {
            return previousCPUReading
        }

        guard cpuInitialSampleIntervalNanoseconds > 0 else {
            return nil
        }

        let initialReading = cpuReader()
        guard initialReading != nil else {
            return nil
        }

        try? await Task.sleep(nanoseconds: cpuInitialSampleIntervalNanoseconds)
        return initialReading
    }

    func history(for module: SpillStatusModule) -> [Double] {
        snapshot.metricHistory[module] ?? []
    }
}

private extension SystemStatusStore {
    private func appendHistory(
        _ value: Double,
        for module: SpillStatusModule,
        state: SpillStatusState,
        to snapshot: inout SystemStatusSnapshot
    ) {
        guard state != .unavailable, value.isFinite else {
            return
        }

        snapshot.metricHistory[module] = appendedHistoryValue(
            value,
            to: snapshot.metricHistory[module] ?? []
        )
    }

    private func appendNetworkTrafficHistory(
        _ status: SystemNetworkStatus,
        to snapshot: inout SystemStatusSnapshot
    ) {
        guard status.state != .unavailable else {
            return
        }

        snapshot.networkTrafficHistory = SystemNetworkTrafficHistory(
            received: appendedHistoryValue(
                status.receivedActivityRatio,
                to: snapshot.networkTrafficHistory.received
            ),
            sent: appendedHistoryValue(
                status.sentActivityRatio,
                to: snapshot.networkTrafficHistory.sent
            )
        )
    }

    private func appendCPUCoreHistory(
        _ status: SystemCPUStatus,
        to snapshot: inout SystemStatusSnapshot
    ) {
        guard status.state != .unavailable,
              !status.coreUsageRatios.isEmpty
        else {
            snapshot.cpuCoreHistory = []
            return
        }

        if snapshot.cpuCoreHistory.count != status.coreUsageRatios.count {
            snapshot.cpuCoreHistory = Array(repeating: [], count: status.coreUsageRatios.count)
        }

        snapshot.cpuCoreHistory = status.coreUsageRatios.enumerated().map { index, ratio in
            appendedHistoryValue(ratio, to: snapshot.cpuCoreHistory[index])
        }
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

    private static func initialCoreHistory(for values: [Double], state: SpillStatusState) -> [[Double]] {
        guard state != .unavailable else {
            return []
        }

        return values.map { value in
            value.isFinite ? [value.clamped(to: 0...1)] : []
        }
    }
}

private extension SystemStatusStore {
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
