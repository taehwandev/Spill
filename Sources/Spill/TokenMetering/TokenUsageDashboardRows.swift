import Foundation

enum TokenUsageDashboardRowBuilder {
    static func rows<Key: Hashable>(
        tokenValues: [Key: Int],
        totalTokens: Int,
        displayMode: TokenUsageDisplayMode,
        id: (Key) -> String,
        label: (Key) -> String
    ) -> [TokenUsageDashboardBarRow] {
        rows(
            candidates: Array(tokenValues.keys),
            totalTokens: totalTokens,
            displayMode: displayMode,
            tokens: { tokenValues[$0, default: 0] },
            id: id,
            label: label
        )
    }

    static func rawRows<Key: Hashable & RawRepresentable>(
        tokenValues: [String: Int],
        totalTokens: Int,
        displayMode: TokenUsageDisplayMode,
        id: (Key) -> String,
        label: (Key) -> String
    ) -> [TokenUsageDashboardBarRow] where Key.RawValue == String {
        rows(
            tokenValues: tokenValues.reduce(into: [Key: Int]()) { totals, element in
                guard let key = Key(rawValue: element.key) else {
                    return
                }
                totals[key] = element.value
            },
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: id,
            label: label
        )
    }

    static func rows<Candidate>(
        candidates: [Candidate],
        totalTokens: Int,
        displayMode: TokenUsageDisplayMode,
        tokens: (Candidate) -> Int,
        id: (Candidate) -> String,
        label: (Candidate) -> String,
        sorted: Bool = true
    ) -> [TokenUsageDashboardBarRow] {
        let rows = candidates.compactMap { candidate -> TokenUsageDashboardBarRow? in
            let tokenCount = tokens(candidate)
            guard tokenCount > 0 else {
                return nil
            }

            let ratio = TokenUsageDashboardSnapshot.chartRatio(tokens: tokenCount, totalTokens: totalTokens)
            let value: String
            switch displayMode {
            case .tokens:
                value = TokenUsageDashboardSnapshot.formatTokens(tokenCount)
            case .percentage:
                value = TokenUsageDashboardSnapshot.formatPercentage(ratio * 100.0)
            }

            return TokenUsageDashboardBarRow(
                id: id(candidate),
                title: label(candidate),
                value: value,
                ratio: ratio
            )
        }

        guard sorted else {
            return rows
        }

        return rows.sorted { lhs, rhs in
            if lhs.ratio == rhs.ratio {
                return lhs.title < rhs.title
            }
            return lhs.ratio > rhs.ratio
        }
    }
}

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
