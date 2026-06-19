import Foundation

enum TokenUsageDashboardRowBuilder {
    static func rows<Key: Hashable>(
        tokenValues: [Key: Int],
        totalTokens: Int,
        id: (Key) -> String,
        label: (Key) -> String
    ) -> [TokenUsageDashboardBarRow] {
        rows(
            candidates: Array(tokenValues.keys),
            totalTokens: totalTokens,
            tokens: { tokenValues[$0, default: 0] },
            id: id,
            label: label
        )
    }

    static func rawRows<Key: Hashable & RawRepresentable>(
        tokenValues: [String: Int],
        totalTokens: Int,
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
            id: id,
            label: label
        )
    }

    static func rows<Candidate>(
        candidates: [Candidate],
        totalTokens: Int,
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
            let tokensString = TokenUsageDashboardSnapshot.formatTokens(tokenCount)
            let pctString = TokenUsageDashboardSnapshot.formatPercentage(ratio * 100.0)
            let value = "\(tokensString) (\(pctString))"

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
