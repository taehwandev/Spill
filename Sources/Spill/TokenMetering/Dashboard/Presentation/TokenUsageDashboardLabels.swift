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

    /// Short name for dense detail areas (breakdown rows, per-tool legends,
    /// trend rows). The tool tabs above keep the full `dashboardLabel`, so
    /// "agy" is already introduced there as Antigravity.
    func compactDashboardLabel(language: TokenMeteringLanguage) -> String {
        switch self {
        case .antigravity:
            return "agy"
        default:
            return dashboardLabel(language: language)
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
