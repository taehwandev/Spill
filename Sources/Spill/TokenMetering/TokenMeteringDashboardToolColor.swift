import SwiftUI

enum TokenMeteringDashboardToolPalette {
    static let codex = Color(red: 0.04, green: 0.76, blue: 0.79)
    static let claude = Color(red: 0.86, green: 0.45, blue: 0.28)
    static let antigravity = Color(red: 0.12, green: 0.55, blue: 0.96)
    static let openAI = Color(red: 0.09, green: 0.62, blue: 0.45)
}

extension TokenUsageAITool {
    var dashboardTint: Color {
        switch self {
        case .codex:
            return TokenMeteringDashboardToolPalette.codex
        case .claude:
            return TokenMeteringDashboardToolPalette.claude
        case .antigravity:
            return TokenMeteringDashboardToolPalette.antigravity
        case .openAI:
            return TokenMeteringDashboardToolPalette.openAI
        case .unknown:
            return .secondary
        }
    }
}

extension LocalAIToolKind {
    var dashboardTint: Color {
        switch self {
        case .codex:
            return TokenUsageAITool.codex.dashboardTint
        case .claude:
            return TokenUsageAITool.claude.dashboardTint
        case .antigravity:
            return TokenUsageAITool.antigravity.dashboardTint
        case .ollama:
            return .green
        case .openAI:
            return TokenUsageAITool.openAI.dashboardTint
        }
    }
}
