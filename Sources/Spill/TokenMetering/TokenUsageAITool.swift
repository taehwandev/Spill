enum TokenUsageAITool: String, Codable, CaseIterable, Sendable {
    case unknown
    case codex
    case claude
    case antigravity
    case openAI = "openai"

    static let dashboardTools: [Self] = [.codex, .claude, .antigravity]

    var isDashboardTool: Bool {
        Self.dashboardTools.contains(self)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "ollama" {
            self = .unknown
            return
        }
        if value == "agy" {
            self = .antigravity
            return
        }

        guard let tool = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported token usage ai_tool label."
            )
        }
        self = tool
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
