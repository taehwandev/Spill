import Foundation

extension TokenUsageAITool {
    var dashboardLabel: String {
        dashboardLabel(language: .current())
    }

    func dashboardLabel(language: TokenMeteringLanguage) -> String {
        switch self {
        case .unknown:
            return TokenMeteringL10n.text(.unknownAITool, language: language)
        case .codex:
            return "Codex"
        case .claude:
            return "Claude"
        case .antigravity:
            return "Antigravity (agy)"
        case .openAI:
            return "OpenAI"
        }
    }
}

extension TokenUsageTaskType {
    func dashboardLabel(language: TokenMeteringLanguage) -> String {
        TokenMeteringL10n.taskLabel(rawValue, language: language)
    }
}

extension TokenUsageStage {
    func dashboardLabel(language: TokenMeteringLanguage) -> String {
        TokenMeteringL10n.stageLabel(rawValue, language: language)
    }
}
