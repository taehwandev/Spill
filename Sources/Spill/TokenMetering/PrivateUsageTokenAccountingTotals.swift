struct PrivateUsageTokenAccountingTotals: Codable, Equatable, Sendable {
    var accountedEventCount: Int
    var unclassifiedEventCount: Int
    var uncachedInputTokens: Int
    var cacheCreationInputTokens: Int
    var cacheReadInputTokens: Int
    var unclassifiedInputTokens: Int
    var reasoningOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case accountedEventCount = "accounted_event_count"
        case unclassifiedEventCount = "unclassified_event_count"
        case uncachedInputTokens = "uncached_input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case unclassifiedInputTokens = "unclassified_input_tokens"
        case reasoningOutputTokens = "reasoning_output_tokens"
    }

    static let zero = PrivateUsageTokenAccountingTotals(
        accountedEventCount: 0,
        unclassifiedEventCount: 0,
        uncachedInputTokens: 0,
        cacheCreationInputTokens: 0,
        cacheReadInputTokens: 0,
        unclassifiedInputTokens: 0,
        reasoningOutputTokens: 0
    )

    mutating func add(_ event: TokenUsageEvent) {
        if let accounting = event.tokenAccounting {
            accountedEventCount += 1
            uncachedInputTokens += accounting.uncachedInputTokens
            cacheCreationInputTokens += accounting.cacheCreationInputTokens
            cacheReadInputTokens += accounting.cacheReadInputTokens
            reasoningOutputTokens += accounting.reasoningOutputTokens
        } else {
            unclassifiedEventCount += 1
            unclassifiedInputTokens += event.inputTokens
        }
    }

    mutating func add(_ totals: PrivateUsageTokenAccountingTotals) {
        accountedEventCount += totals.accountedEventCount
        unclassifiedEventCount += totals.unclassifiedEventCount
        uncachedInputTokens += totals.uncachedInputTokens
        cacheCreationInputTokens += totals.cacheCreationInputTokens
        cacheReadInputTokens += totals.cacheReadInputTokens
        unclassifiedInputTokens += totals.unclassifiedInputTokens
        reasoningOutputTokens += totals.reasoningOutputTokens
    }
}
