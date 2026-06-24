import Foundation

struct LocalAIProcessSummary: Hashable, Sendable {
    static let empty = LocalAIProcessSummary(processes: [], fallbackProcessCount: 0)

    let processes: [LocalAIProcessSnapshot]
    let processCount: Int
    let cpuPercent: Double
    let memoryBytes: UInt64
    let hasAvailableMetrics: Bool

    init(processes: [LocalAIProcessSnapshot], fallbackProcessCount: Int = 0) {
        self.processes = processes.sorted { lhs, rhs in
            if lhs.cpuPercent == rhs.cpuPercent {
                return lhs.processID < rhs.processID
            }
            return lhs.cpuPercent > rhs.cpuPercent
        }
        self.processCount = max(processes.count, fallbackProcessCount)
        self.hasAvailableMetrics = processes.contains { $0.metricsAvailable }
        self.cpuPercent = processes.reduce(0) { $0 + ($1.metricsAvailable ? $1.cpuPercent : 0) }
        self.memoryBytes = processes.reduce(0) { $0 + ($1.metricsAvailable ? $1.memoryBytes : 0) }
    }

    var isRunning: Bool {
        processCount > 0
    }

    var cpuPercentText: String {
        Self.formatCPUPercent(cpuPercent, isAvailable: hasAvailableMetrics)
    }

    var memoryText: String {
        hasAvailableMetrics ? SystemMemoryProvider.formatBytes(memoryBytes) : Self.unavailableMetricText
    }

    static let unavailableMetricText = "N/A"

    static func formatCPUPercent(_ value: Double, isAvailable: Bool = true) -> String {
        guard isAvailable else {
            return unavailableMetricText
        }
        if value > 100 {
            return "100%+"
        }
        if value >= 10 {
            return String(format: "%.0f%%", value)
        }
        return String(format: "%.1f%%", value)
    }
}
