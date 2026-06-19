import Foundation

struct TokenMeteringDashboardAgentStatusSummary: Equatable {
    let rows: [TokenMeteringDashboardAgentStatusRow]
    let runningToolCount: Int
    let processCount: Int
    let cpuText: String
    let memoryText: String

    var detectedToolCount: Int {
        rows.count
    }

    static func make(statuses: [LocalAIToolStatus]) -> TokenMeteringDashboardAgentStatusSummary {
        let dashboardStatuses = statuses.filter(\.kind.isTokenDashboardAgentTool)
        let rows = dashboardStatuses.map { status in
            TokenMeteringDashboardAgentStatusRow(status: status)
        }
        let totalCPU = dashboardStatuses.reduce(0) { $0 + $1.processSummary.cpuPercent }
        let totalMemory = dashboardStatuses.reduce(UInt64(0)) { $0 + $1.processSummary.memoryBytes }
        let hasAvailableMetrics = dashboardStatuses.contains { $0.processSummary.hasAvailableMetrics }

        return TokenMeteringDashboardAgentStatusSummary(
            rows: rows,
            runningToolCount: rows.filter(\.isRunning).count,
            processCount: rows.reduce(0) { $0 + $1.processCount },
            cpuText: LocalAIProcessSummary.formatCPUPercent(totalCPU, isAvailable: hasAvailableMetrics),
            memoryText: hasAvailableMetrics ? SystemMemoryProvider.formatBytes(totalMemory) : LocalAIProcessSummary.unavailableMetricText
        )
    }
}
