import Foundation

/// One aggregate row of the single grouped scan behind the dashboard snapshot. Every field is
/// a plain SUM/COUNT, so any coarser grouping (tool, project, task, ...) is an exact roll-up
/// of these rows and no further statement has to touch the events table for the same range.
struct DashboardGroupedAggregateRow: Equatable {
    /// Raw stored label; roll-ups map it with `TokenUsageStore.dashboardTool(storedLabel:)`.
    let toolLabel: String
    let projectID: String?
    let taskType: String?
    let stage: String?
    let modelKey: String?
    let eventCount: Int
    let totalTokens: Int
    let freshTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let uncachedInput: Int
    let cacheCreationInput: Int
    let cacheReadInput: Int
    let unclassifiedInput: Int
    /// Rows with `input_tokens > 0`: the only rows the input accounting split considers.
    let inputEventCount: Int
    let sources: [String: Int]

    var tool: TokenUsageAITool { TokenUsageStore.dashboardTool(storedLabel: toolLabel) }

    /// Mirrors TokenUsageWorkflowAssistance.isAssisted in SQL three-valued logic: a NULL
    /// column never satisfies its half of the comparison.
    var isAssisted: Bool {
        (taskType.map { $0 != "uncategorized" } ?? false) || (stage.map { $0 != "summarize" } ?? false)
    }

    var inputScopeTotals: TokenUsageInputScopeTotals {
        TokenUsageInputScopeTotals(includeCache: totalTokens, freshOnly: freshTokens)
    }
}
