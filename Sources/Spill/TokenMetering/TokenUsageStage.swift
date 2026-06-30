struct TokenUsageStage: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init?(rawValue: String) {
        guard Self.isSafeSlug(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        precondition(Self.isSafeSlug(value), "Unsafe token usage stage slug.")
        rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard Self.isSafeSlug(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsafe token usage stage slug."
            )
        }
        rawValue = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var isSafe: Bool {
        Self.isSafeSlug(rawValue)
    }

    static let monitor: Self = "monitor"
    static let classify: Self = "classify"
    static let plan: Self = "plan"
    static let draft: Self = "draft"
    static let revise: Self = "revise"
    static let implement: Self = "implement"
    static let verify: Self = "verify"
    static let summarize: Self = "summarize"

    static func custom(_ rawValue: String) -> Self? {
        Self(rawValue: rawValue)
    }

    private static func isSafeSlug(_ value: String) -> Bool {
        value.range(of: #"^[a-z][a-z0-9_]{1,40}$"#, options: .regularExpression) != nil
    }
}
