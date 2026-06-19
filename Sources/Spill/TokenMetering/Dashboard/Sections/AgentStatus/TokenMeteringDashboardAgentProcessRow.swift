import Foundation

struct TokenMeteringDashboardAgentProcessRow: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String

    init(process: LocalAIProcessSnapshot) {
        let cpuText = LocalAIProcessSummary.formatCPUPercent(process.cpuPercent, isAvailable: process.metricsAvailable)
        let memoryText = process.metricsAvailable
            ? SystemMemoryProvider.formatBytes(process.memoryBytes)
            : LocalAIProcessSummary.unavailableMetricText

        id = "\(process.processID)"
        title = "pid \(process.processID)"
        detail = [
            process.executableName,
            "CPU \(cpuText)",
            memoryText
        ].joined(separator: " / ")
    }
}
