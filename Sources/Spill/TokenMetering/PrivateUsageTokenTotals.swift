struct PrivateUsageTokenTotals: Codable, Equatable, Sendable {
    var eventCount: Int
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
    var latencyMS: Int
    var accounting: PrivateUsageTokenAccountingTotals

    enum CodingKeys: String, CodingKey {
        case eventCount = "event_count"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
        case latencyMS = "latency_ms"
        case accounting
    }

    static let zero = PrivateUsageTokenTotals(
        eventCount: 0,
        inputTokens: 0,
        outputTokens: 0,
        totalTokens: 0,
        latencyMS: 0,
        accounting: .zero
    )

    init(
        eventCount: Int,
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        latencyMS: Int,
        accounting: PrivateUsageTokenAccountingTotals = .zero
    ) {
        self.eventCount = eventCount
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.latencyMS = latencyMS
        self.accounting = accounting
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventCount = try container.decode(Int.self, forKey: .eventCount)
        inputTokens = try container.decode(Int.self, forKey: .inputTokens)
        outputTokens = try container.decode(Int.self, forKey: .outputTokens)
        totalTokens = try container.decode(Int.self, forKey: .totalTokens)
        latencyMS = try container.decode(Int.self, forKey: .latencyMS)
        accounting = try container.decodeIfPresent(
            PrivateUsageTokenAccountingTotals.self,
            forKey: .accounting
        ) ?? .zero
    }

    mutating func add(_ event: TokenUsageEvent) {
        eventCount += 1
        inputTokens += event.inputTokens
        outputTokens += event.outputTokens
        totalTokens += event.totalTokens
        latencyMS += event.latencyMS
        accounting.add(event)
    }
}
