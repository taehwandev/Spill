import Darwin
import Foundation

struct SystemCPUReading: Hashable, Sendable {
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

struct SystemCPUStatus: Hashable, Sendable {
    let value: String
    let subtitle: String?
    let usageRatio: Double
    let activeTicks: UInt64
    let totalTicks: UInt64
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

    static func status(sampleIntervalNanoseconds: UInt64 = 120_000_000) async -> SystemCPUStatus {
        let previous = SystemCPUReader.current()
        try? await Task.sleep(nanoseconds: sampleIntervalNanoseconds)
        let current = SystemCPUReader.current()

        return status(previous: previous, current: current)
    }

    static func status(previous: SystemCPUReading?, current: SystemCPUReading?) -> SystemCPUStatus {
        guard let previous, let current else {
            return unavailableStatus()
        }

        guard current.totalTicks >= previous.totalTicks,
              current.activeTicks >= previous.activeTicks,
              current.idleTicks >= previous.idleTicks
        else {
            return unavailableStatus()
        }

        let activeDelta = current.activeTicks - previous.activeTicks
        let totalDelta = current.totalTicks - previous.totalTicks

        guard totalDelta > 0 else {
            return unavailableStatus()
        }

        let ratio = (Double(activeDelta) / Double(totalDelta)).clamped(to: 0...1)

        return SystemCPUStatus(
            value: "\(Int((ratio * 100).rounded()))%",
            subtitle: "Active",
            usageRatio: ratio,
            activeTicks: activeDelta,
            totalTicks: totalDelta,
            state: state(for: ratio)
        )
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

    private static func unavailableStatus() -> SystemCPUStatus {
        SystemCPUStatus(
            value: "N/A",
            subtitle: nil,
            usageRatio: 0,
            activeTicks: 0,
            totalTicks: 0,
            state: .unavailable
        )
    }
}

private enum SystemCPUReader {
    static func current() -> SystemCPUReading? {
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

        return SystemCPUReading(
            userTicks: UInt64(cpuLoad.cpu_ticks.0),
            systemTicks: UInt64(cpuLoad.cpu_ticks.1),
            idleTicks: UInt64(cpuLoad.cpu_ticks.2),
            niceTicks: UInt64(cpuLoad.cpu_ticks.3)
        )
    }
}

private extension UInt64 {
    func saturatingAdd(_ value: UInt64) -> UInt64 {
        let (result, overflow) = addingReportingOverflow(value)
        return overflow ? UInt64.max : result
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
