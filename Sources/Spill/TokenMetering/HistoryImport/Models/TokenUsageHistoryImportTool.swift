import Foundation

enum TokenUsageHistoryImportTool: String, CaseIterable, Hashable, Identifiable, Sendable {
    case codex
    case claude
    case antigravity

    var id: String { rawValue }

    var aiTool: TokenUsageAITool {
        switch self {
        case .codex:
            return .codex
        case .claude:
            return .claude
        case .antigravity:
            return .antigravity
        }
    }
}
