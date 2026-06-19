import Foundation

struct TokenMeteringDashboardAgentStatusRow: Identifiable, Equatable {
    let id: String
    let kind: LocalAIToolKind
    let title: String
    let symbolName: String
    let statusValue: String
    let detail: String
    let isRunning: Bool
    let processCount: Int
    let cpuText: String
    let memoryText: String
    let metadataRows: [TokenMeteringDashboardAgentMetadataRow]
    let processRows: [TokenMeteringDashboardAgentProcessRow]

    init(status: LocalAIToolStatus) {
        id = status.id
        kind = status.kind
        title = status.title
        symbolName = status.symbolName
        statusValue = status.value
        detail = status.subtitle ?? "N/A"
        isRunning = status.hasRunningProcesses
        processCount = status.processSummary.processCount
        cpuText = status.processSummary.cpuPercentText
        memoryText = status.processSummary.memoryText
        metadataRows = Self.metadataRows(for: status)
        processRows = status.processSummary.processes.prefix(3).map {
            TokenMeteringDashboardAgentProcessRow(process: $0)
        }
    }

    private static func metadataRows(for status: LocalAIToolStatus) -> [TokenMeteringDashboardAgentMetadataRow] {
        [
            status.metadata.model.map { TokenMeteringDashboardAgentMetadataRow(label: AppL10n.text(.model), value: $0) },
            status.metadata.version.map { TokenMeteringDashboardAgentMetadataRow(label: AppL10n.text(.version), value: "v\($0)") },
            status.metadata.source.map { TokenMeteringDashboardAgentMetadataRow(label: AppL10n.text(.source), value: $0) }
        ].compactMap { $0 }
    }
}
