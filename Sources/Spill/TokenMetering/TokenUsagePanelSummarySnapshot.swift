import Foundation

struct TokenUsagePanelSummarySnapshot: Equatable {
    let eventCount: Int
    let totalTokens: Int
    let displayMode: TokenUsageDisplayMode
    let toolRows: [TokenUsageDashboardBarRow]
    let taskRows: [TokenUsageDashboardBarRow]
    let sourceRows: [TokenUsageDashboardBarRow]

    init(
        summary: TokenUsageDashboardSummary,
        displayMode: TokenUsageDisplayMode = .tokens,
        language: TokenMeteringLanguage = .current()
    ) {
        eventCount = summary.eventCount
        totalTokens = summary.totalTokens
        self.displayMode = displayMode

        toolRows = TokenUsageDashboardRowBuilder.rawRows(
            tokenValues: summary.toolTotals,
            totalTokens: summary.totalTokens,
            displayMode: displayMode,
            id: { (tool: TokenUsageAITool) in tool.rawValue },
            label: { (tool: TokenUsageAITool) in tool.dashboardLabel(language: language) }
        )

        taskRows = TokenUsageDashboardRowBuilder.rawRows(
            tokenValues: summary.taskTotals,
            totalTokens: summary.totalTokens,
            displayMode: displayMode,
            id: { (taskType: TokenUsageTaskType) in taskType.rawValue },
            label: { (taskType: TokenUsageTaskType) in taskType.dashboardLabel(language: language) }
        )

        sourceRows = TokenUsageDashboardRowBuilder.rawRows(
            tokenValues: summary.sourceTotals,
            totalTokens: summary.totalTokens,
            displayMode: displayMode,
            id: { (source: TokenUsageSource) in source.rawValue },
            label: { (source: TokenUsageSource) in source.label(language: language) }
        )
    }

    init(snapshot: TokenUsageDashboardSnapshot) {
        eventCount = snapshot.eventCount
        totalTokens = snapshot.totalTokens
        displayMode = snapshot.displayMode
        toolRows = snapshot.toolRows
        taskRows = snapshot.taskRows
        sourceRows = snapshot.sourceRows
    }

    static let empty = TokenUsagePanelSummarySnapshot(summary: .empty)
}
