import Foundation

enum TokenUsageSource: String, Hashable {
    case system
    case user
    case history
    case repoContext = "repo_context"
    case toolOutput = "tool_output"
    case generatedOutput = "generated_output"
    case unknown

    func label(language: TokenMeteringLanguage) -> String {
        switch self {
        case .system:
            return TokenMeteringL10n.text(.sourceSystem, language: language)
        case .user:
            return TokenMeteringL10n.text(.sourceUser, language: language)
        case .history:
            return TokenMeteringL10n.text(.sourceHistory, language: language)
        case .repoContext:
            return TokenMeteringL10n.text(.sourceRepoContext, language: language)
        case .toolOutput:
            return TokenMeteringL10n.text(.sourceToolOutput, language: language)
        case .generatedOutput:
            return TokenMeteringL10n.text(.sourceGeneratedOutput, language: language)
        case .unknown:
            return TokenMeteringL10n.text(.sourceUnavailable, language: language)
        }
    }
}
