import Foundation

struct TokenUsageDashboardToolFilter: Identifiable, Equatable {
    let tool: TokenUsageAITool?
    let title: String
    let detail: String
    let shareLabel: String?
    let isSelected: Bool

    var id: String {
        tool?.rawValue ?? "all"
    }
}
