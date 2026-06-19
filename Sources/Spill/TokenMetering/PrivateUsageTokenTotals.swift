struct PrivateUsageTokenTotals: Codable, Equatable, Sendable {
    var eventCount: Int
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
    var latencyMS: Int

    enum CodingKeys: String, CodingKey {
        case eventCount = "event_count"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
        case latencyMS = "latency_ms"
    }

    static let zero = PrivateUsageTokenTotals(
        eventCount: 0,
        inputTokens: 0,
        outputTokens: 0,
        totalTokens: 0,
        latencyMS: 0
    )

    mutating func add(_ event: TokenUsageEvent) {
        eventCount += 1
        inputTokens += event.inputTokens
        outputTokens += event.outputTokens
        totalTokens += event.totalTokens
        latencyMS += event.latencyMS
    }
}
