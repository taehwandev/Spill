import Foundation

struct TokenUsageInputScopeTotals: Equatable, Sendable {
    let includeCache: Int
    let freshOnly: Int

    static let zero = TokenUsageInputScopeTotals(includeCache: 0, freshOnly: 0)

    init(includeCache: Int, freshOnly: Int) {
        self.includeCache = includeCache
        self.freshOnly = freshOnly
    }

    init(
        totalTokens: Int,
        rawInputTokens: Int,
        exactFreshInputTokens: Int
    ) {
        self.init(
            includeCache: totalTokens,
            freshOnly: exactFreshInputTokens + max(0, totalTokens - rawInputTokens)
        )
    }

    func total(for scope: TokenUsageInputScope) -> Int {
        switch scope {
        case .includeCache:
            includeCache
        case .freshOnly:
            freshOnly
        }
    }
}
