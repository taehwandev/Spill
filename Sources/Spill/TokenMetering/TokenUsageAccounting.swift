struct TokenUsageAccounting: Codable, Equatable, Sendable {
    let uncachedInputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int
    let reasoningOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case uncachedInputTokens = "uncached_input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case reasoningOutputTokens = "reasoning_output_tokens"
    }

    init(
        uncachedInputTokens: Int,
        cacheCreationInputTokens: Int = 0,
        cacheReadInputTokens: Int = 0,
        reasoningOutputTokens: Int = 0
    ) {
        self.uncachedInputTokens = uncachedInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
    }

    var measuredInputTokens: Int {
        Self.safeSum([uncachedInputTokens, cacheCreationInputTokens, cacheReadInputTokens]) ?? Int.max
    }

    func validate(inputTokens: Int, outputTokens: Int) throws {
        for value in [uncachedInputTokens, cacheCreationInputTokens, cacheReadInputTokens, reasoningOutputTokens] where value < 0 {
            throw TokenUsageValidationError.invalidRequiredField
        }
        guard let measuredInputTokens = Self.safeSum([
            uncachedInputTokens,
            cacheCreationInputTokens,
            cacheReadInputTokens
        ]) else {
            throw TokenUsageValidationError.invalidRequiredField
        }
        guard measuredInputTokens <= inputTokens,
              reasoningOutputTokens <= outputTokens
        else {
            throw TokenUsageValidationError.invalidRequiredField
        }
    }

    private static func safeSum(_ values: [Int]) -> Int? {
        values.reduce(Optional(0)) { partialResult, value in
            guard let partialResult else { return nil }
            let result = partialResult.addingReportingOverflow(value)
            return result.overflow ? nil : result.partialValue
        }
    }
}
