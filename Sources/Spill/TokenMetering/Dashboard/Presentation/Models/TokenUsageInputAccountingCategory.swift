import Foundation

enum TokenUsageInputAccountingCategory: String, CaseIterable, Hashable {
    case uncachedInput = "uncached_input"
    case cacheCreationInput = "cache_creation_input"
    case cacheReadInput = "cache_read_input"
    case unclassifiedInput = "unclassified_input"

    func label(language: TokenMeteringLanguage) -> String {
        switch self {
        case .uncachedInput:
            return TokenMeteringL10n.text(.inputAccountingUncached, language: language)
        case .cacheCreationInput:
            return TokenMeteringL10n.text(.inputAccountingCacheCreation, language: language)
        case .cacheReadInput:
            return TokenMeteringL10n.text(.inputAccountingCacheRead, language: language)
        case .unclassifiedInput:
            return TokenMeteringL10n.text(.inputAccountingUnclassified, language: language)
        }
    }
}
