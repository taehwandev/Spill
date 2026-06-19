import Foundation

enum TokenUsageClearScope: Equatable, Identifiable {
    case all
    case currentScope
    case tool(TokenUsageAITool)
    case period(TokenUsageDashboardPeriod)
    case workItem(String)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .currentScope:
            return "current_scope"
        case let .tool(tool):
            return "tool_\(tool.rawValue)"
        case let .period(period):
            return "period_\(period.rawValue)"
        case let .workItem(id):
            return "work_item_\(id)"
        }
    }
}
