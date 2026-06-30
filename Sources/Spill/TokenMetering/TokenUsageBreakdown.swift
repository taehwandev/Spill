struct TokenUsageBreakdown: Codable, Equatable, Sendable {
    let system: Int
    let user: Int
    let history: Int
    let repoContext: Int
    let toolOutput: Int
    let generatedOutput: Int
    let unknown: Int

    enum CodingKeys: String, CodingKey, CaseIterable {
        case system
        case user
        case history
        case repoContext = "repo_context"
        case toolOutput = "tool_output"
        case generatedOutput = "generated_output"
        case unknown
    }

    init(
        system: Int,
        user: Int,
        history: Int,
        repoContext: Int,
        toolOutput: Int,
        generatedOutput: Int,
        unknown: Int = 0
    ) {
        self.system = system
        self.user = user
        self.history = history
        self.repoContext = repoContext
        self.toolOutput = toolOutput
        self.generatedOutput = generatedOutput
        self.unknown = unknown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        system = try container.decode(Int.self, forKey: .system)
        user = try container.decode(Int.self, forKey: .user)
        history = try container.decode(Int.self, forKey: .history)
        repoContext = try container.decode(Int.self, forKey: .repoContext)
        toolOutput = try container.decode(Int.self, forKey: .toolOutput)
        generatedOutput = try container.decode(Int.self, forKey: .generatedOutput)
        unknown = try container.decodeIfPresent(Int.self, forKey: .unknown) ?? 0
        try validate()
    }

    var total: Int {
        system + user + history + repoContext + toolOutput + generatedOutput + unknown
    }

    func validate() throws {
        for value in [system, user, history, repoContext, toolOutput, generatedOutput, unknown] where value < 0 {
            throw TokenUsageValidationError.invalidRequiredField
        }
    }
}
