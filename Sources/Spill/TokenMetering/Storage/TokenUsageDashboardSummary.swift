import Foundation

struct TokenUsageDashboardSummary: Equatable {
    let eventCount: Int
    let totalTokens: Int
    let exactFreshTotalTokens: Int
    let toolTotals: [String: Int]
    let taskTotals: [String: Int]
    let sourceTotals: [String: Int]

    static let empty = TokenUsageDashboardSummary(
        eventCount: 0,
        totalTokens: 0,
        exactFreshTotalTokens: 0,
        toolTotals: [:],
        taskTotals: [:],
        sourceTotals: [:]
    )
}
