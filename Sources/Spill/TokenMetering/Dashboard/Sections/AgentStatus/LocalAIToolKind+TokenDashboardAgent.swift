import Foundation

extension LocalAIToolKind {
    var tokenUsageDashboardTool: TokenUsageAITool? {
        switch self {
        case .codex:
            return .codex
        case .claude:
            return .claude
        case .antigravity:
            return .antigravity
        case .ollama, .openAI:
            return nil
        }
    }

    var isTokenDashboardAgentTool: Bool {
        switch self {
        case .codex, .claude, .antigravity:
            return true
        case .ollama, .openAI:
            return false
        }
    }
}

extension TokenUsageAITool {
    var localAIToolKind: LocalAIToolKind? {
        switch self {
        case .codex:
            return .codex
        case .claude:
            return .claude
        case .antigravity:
            return .antigravity
        case .unknown, .openAI:
            return nil
        }
    }
}
