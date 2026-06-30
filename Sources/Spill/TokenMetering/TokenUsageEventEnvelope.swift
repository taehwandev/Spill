struct TokenUsageEventEnvelope: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let source: String
    let events: [TokenUsageEvent]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case source
        case events
    }
}
