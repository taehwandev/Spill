import Foundation

struct TokenUsageDashboardBarRow: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let ratio: Double
    /// Per-AI-tool split of this row's tokens, in canonical tool order. Empty for rows that are not
    /// broken down by tool (tool, model, and source rows).
    var toolShares: [TokenUsageDashboardToolShare] = []
}
