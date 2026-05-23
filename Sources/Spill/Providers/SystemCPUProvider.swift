import Darwin
import Foundation

struct SystemCPUCoreReading: Hashable, Sendable {
    let userTicks: UInt64
    let systemTicks: UInt64
    let idleTicks: UInt64
    let niceTicks: UInt64

    var activeTicks: UInt64 {
        userTicks.saturatingAdd(systemTicks).saturatingAdd(niceTicks)
    }

    var totalTicks: UInt64 {
        activeTicks.saturatingAdd(idleTicks)
    }
}

struct SystemCPUReading: Hashable, Sendable {
    let userTicks: UInt64
    let systemTicks: UInt64
    let idleTicks: UInt64
    let niceTicks: UInt64
    let coreReadings: [SystemCPUCoreReading]

    init(
        userTicks: UInt64,
        systemTicks: UInt64,
        idleTicks: UInt64,
        niceTicks: UInt64,
        coreReadings: [SystemCPUCoreReading] = []
    ) {
        self.userTicks = userTicks
        self.systemTicks = systemTicks
        self.idleTicks = idleTicks
        self.niceTicks = niceTicks
        self.coreReadings = coreReadings
    }

    var activeTicks: UInt64 {
        userTicks.saturatingAdd(systemTicks).saturatingAdd(niceTicks)
    }

    var totalTicks: UInt64 {
        activeTicks.saturatingAdd(idleTicks)
    }
}

struct SystemCPUStatus: Hashable, Sendable {
    let value: String
    let subtitle: String?
    let usageRatio: Double
    let availableRatio: Double
    let userRatio: Double
    let systemRatio: Double
    let idleRatio: Double
    let niceRatio: Double
    let activeTicks: UInt64
    let totalTicks: UInt64
    let coreUsageRatios: [Double]
    let peakCoreUsageRatio: Double
    let coreCount: Int
    let state: SpillStatusState

    var statusItem: SpillStatusItem {
        SpillStatusItem(
            id: "cpu",
            providerID: SystemCPUProvider.providerID,
            title: "CPU",
            value: value,
            subtitle: subtitle,
            symbolName: "cpu",
            state: state,
            sortPriority: 5
        )
    }
}

struct SystemCPUProvider: SpillStatusProvider {
    static let providerID = SpillProviderID(rawValue: "system")

    let id = "system.cpu"
    let title = "CPU"

    func snapshot() async -> [SpillStatusItem] {
        [(await Self.status()).statusItem]
    }

    static func status(sampleIntervalNanoseconds: UInt64 = 500_000_000) async -> SystemCPUStatus {
        let previous = SystemCPUReader.current()
        try? await Task.sleep(nanoseconds: sampleIntervalNanoseconds)
        let current = SystemCPUReader.current()

        return status(previous: previous, current: current)
    }

    static func currentReading() -> SystemCPUReading? {
        SystemCPUReader.current()
    }

    static func processorTick(_ value: integer_t) -> UInt64 {
        UInt64(UInt32(bitPattern: value))
    }

    static func status(previous: SystemCPUReading?, current: SystemCPUReading?) -> SystemCPUStatus {
        guard let previous else {
            return samplingStatus()
        }

        guard let current else {
            return unavailableStatus()
        }

        guard current.totalTicks >= previous.totalTicks,
              current.activeTicks >= previous.activeTicks,
              current.idleTicks >= previous.idleTicks,
              current.userTicks >= previous.userTicks,
              current.systemTicks >= previous.systemTicks,
              current.niceTicks >= previous.niceTicks
        else {
            return unavailableStatus()
        }

        let activeDelta = current.activeTicks - previous.activeTicks
        let userDelta = current.userTicks - previous.userTicks
        let systemDelta = current.systemTicks - previous.systemTicks
        let idleDelta = current.idleTicks - previous.idleTicks
        let niceDelta = current.niceTicks - previous.niceTicks
        let totalDelta = current.totalTicks - previous.totalTicks

        guard totalDelta > 0 else {
            return zeroStatus()
        }

        let ratio = (Double(activeDelta) / Double(totalDelta)).clamped(to: 0...1)
        let idleRatio = (Double(idleDelta) / Double(totalDelta)).clamped(to: 0...1)
        let coreUsageRatios = coreUsageRatios(previous: previous.coreReadings, current: current.coreReadings)
        let peakCoreUsageRatio = coreUsageRatios.max() ?? 0

        return SystemCPUStatus(
            value: percentText(ratio),
            subtitle: "\(percentText(idleRatio)) available",
            usageRatio: ratio,
            availableRatio: idleRatio,
            userRatio: (Double(userDelta) / Double(totalDelta)).clamped(to: 0...1),
            systemRatio: (Double(systemDelta) / Double(totalDelta)).clamped(to: 0...1),
            idleRatio: idleRatio,
            niceRatio: (Double(niceDelta) / Double(totalDelta)).clamped(to: 0...1),
            activeTicks: activeDelta,
            totalTicks: totalDelta,
            coreUsageRatios: coreUsageRatios,
            peakCoreUsageRatio: peakCoreUsageRatio,
            coreCount: current.coreReadings.count,
            state: state(for: ratio)
        )
    }

    static func percentText(_ ratio: Double) -> String {
        let clampedRatio = ratio.clamped(to: 0...1)
        guard clampedRatio > 0 else {
            return "0.0%"
        }

        let percent = clampedRatio * 100
        if percent < 0.1 {
            return "<0.1%"
        }

        return String(format: "%.1f%%", percent)
    }

    private static func state(for usageRatio: Double) -> SpillStatusState {
        if usageRatio >= 0.9 {
            return .warning
        }

        if usageRatio >= 0.7 {
            return .active
        }

        return .normal
    }

    static func unavailableStatus() -> SystemCPUStatus {
        SystemCPUStatus(
            value: "N/A",
            subtitle: nil,
            usageRatio: 0,
            availableRatio: 0,
            userRatio: 0,
            systemRatio: 0,
            idleRatio: 0,
            niceRatio: 0,
            activeTicks: 0,
            totalTicks: 0,
            coreUsageRatios: [],
            peakCoreUsageRatio: 0,
            coreCount: 0,
            state: .unavailable
        )
    }

    private static func samplingStatus() -> SystemCPUStatus {
        SystemCPUStatus(
            value: "Sampling",
            subtitle: "Waiting for sample",
            usageRatio: 0,
            availableRatio: 1,
            userRatio: 0,
            systemRatio: 0,
            idleRatio: 1,
            niceRatio: 0,
            activeTicks: 0,
            totalTicks: 0,
            coreUsageRatios: [],
            peakCoreUsageRatio: 0,
            coreCount: 0,
            state: .refreshing
        )
    }

    private static func zeroStatus() -> SystemCPUStatus {
        SystemCPUStatus(
            value: "0.0%",
            subtitle: "100.0% available",
            usageRatio: 0,
            availableRatio: 1,
            userRatio: 0,
            systemRatio: 0,
            idleRatio: 1,
            niceRatio: 0,
            activeTicks: 0,
            totalTicks: 0,
            coreUsageRatios: [],
            peakCoreUsageRatio: 0,
            coreCount: 0,
            state: .normal
        )
    }

    private static func coreUsageRatios(
        previous: [SystemCPUCoreReading],
        current: [SystemCPUCoreReading]
    ) -> [Double] {
        guard !previous.isEmpty, previous.count == current.count else {
            return []
        }

        let ratios: [Double] = zip(previous, current).compactMap { previousCore, currentCore -> Double? in
            guard currentCore.totalTicks >= previousCore.totalTicks,
                  currentCore.activeTicks >= previousCore.activeTicks,
                  currentCore.idleTicks >= previousCore.idleTicks
            else {
                return nil
            }

            let totalDelta = currentCore.totalTicks - previousCore.totalTicks
            guard totalDelta > 0 else {
                return 0
            }

            let activeDelta = currentCore.activeTicks - previousCore.activeTicks
            return (Double(activeDelta) / Double(totalDelta)).clamped(to: 0...1)
        }

        return ratios.count == current.count ? ratios : []
    }
}

private enum SystemCPUReader {
    static func current() -> SystemCPUReading? {
        guard let aggregateReading = aggregateReading() else {
            return nil
        }

        return SystemCPUReading(
            userTicks: aggregateReading.userTicks,
            systemTicks: aggregateReading.systemTicks,
            idleTicks: aggregateReading.idleTicks,
            niceTicks: aggregateReading.niceTicks,
            coreReadings: coreReadings() ?? []
        )
    }

    private static func aggregateReading() -> SystemCPUCoreReading? {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let host = mach_host_self()
        defer {
            mach_port_deallocate(mach_task_self_, host)
        }

        let result = withUnsafeMutablePointer(to: &cpuLoad) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(host, HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        return SystemCPUCoreReading(
            userTicks: UInt64(cpuLoad.cpu_ticks.0),
            systemTicks: UInt64(cpuLoad.cpu_ticks.1),
            idleTicks: UInt64(cpuLoad.cpu_ticks.2),
            niceTicks: UInt64(cpuLoad.cpu_ticks.3)
        )
    }

    private static func coreReadings() -> [SystemCPUCoreReading]? {
        let host = mach_host_self()
        defer {
            mach_port_deallocate(mach_task_self_, host)
        }

        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )
        guard result == KERN_SUCCESS, let processorInfo else {
            return nil
        }
        defer {
            let byteCount = vm_size_t(Int(processorInfoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: processorInfo)), byteCount)
        }

        let stride = Int(CPU_STATE_MAX)
        return (0..<Int(processorCount)).compactMap { index in
            let base = index * stride
            guard base + Int(CPU_STATE_NICE) < Int(processorInfoCount) else {
                return nil
            }

            return SystemCPUCoreReading(
                userTicks: SystemCPUProvider.processorTick(processorInfo[base + Int(CPU_STATE_USER)]),
                systemTicks: SystemCPUProvider.processorTick(processorInfo[base + Int(CPU_STATE_SYSTEM)]),
                idleTicks: SystemCPUProvider.processorTick(processorInfo[base + Int(CPU_STATE_IDLE)]),
                niceTicks: SystemCPUProvider.processorTick(processorInfo[base + Int(CPU_STATE_NICE)])
            )
        }
    }
}
