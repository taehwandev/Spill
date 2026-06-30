struct TokenUsageTaskType: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init?(rawValue: String) {
        guard Self.isSafeSlug(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        precondition(Self.isSafeSlug(value), "Unsafe token usage task_type slug.")
        rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard Self.isSafeSlug(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsafe token usage task_type slug."
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

    static let uncategorized: Self = "uncategorized"
    static let analysis: Self = "analysis"
    static let prdDrafting: Self = "prd_drafting"
    static let architecture: Self = "architecture"
    static let codeGeneration: Self = "code_generation"
    static let uiDesign: Self = "ui_design"
    static let promptDesign: Self = "prompt_design"
    static let refactoring: Self = "refactoring"
    static let codeReview: Self = "code_review"
    static let reviewResponse: Self = "review_response"
    static let testGeneration: Self = "test_generation"
    static let testing: Self = "testing"
    static let buildVerification: Self = "build_verification"
    static let debugging: Self = "debugging"
    static let bugReproduction: Self = "bug_reproduction"
    static let documentation: Self = "documentation"
    static let changelog: Self = "changelog"
    static let releaseNotes: Self = "release_notes"
    static let releasePackaging: Self = "release_packaging"
    static let gitCommit: Self = "git_commit"
    static let commitMessage: Self = "commit_message"
    static let pullRequest: Self = "pull_request"
    static let workflowSetup: Self = "workflow_setup"

    static func custom(_ rawValue: String) -> Self? {
        Self(rawValue: rawValue)
    }

    private static func isSafeSlug(_ value: String) -> Bool {
        value.range(of: #"^[a-z][a-z0-9_]{1,40}$"#, options: .regularExpression) != nil
    }
}
