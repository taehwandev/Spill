import Foundation

extension LocalAIToolKind {
    var isTokenDashboardAgentTool: Bool {
        switch self {
        case .codex, .claude, .antigravity:
            return true
        case .ollama, .openAI:
            return false
        }
    }
}
