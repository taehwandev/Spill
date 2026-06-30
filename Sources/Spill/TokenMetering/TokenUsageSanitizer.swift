import Foundation

enum TokenUsageSanitizer {
    private static let safeEventKeys = Set(TokenUsageEvent.CodingKeys.allCases.map(\.rawValue))
    private static let safeBreakdownKeys = Set(TokenUsageBreakdown.CodingKeys.allCases.map(\.rawValue))
    private static let forbiddenKeys = Set([
        "command",
        "prompt",
        "response",
        "file_path",
        "filePath",
        "path",
        "repo_name",
        "repoName",
        "repository",
        "branch_name",
        "branchName",
        "commit_message",
        "commitMessage",
        "terminal_output",
        "terminalOutput",
        "log_body",
        "logBody",
        "diff",
        "changes",
        "change",
        "source_content",
        "sourceContent",
        "environment_value",
        "environmentValue",
        "secret"
    ])

    static func sanitizeEventJSONData(_ data: Data) throws -> TokenUsageEvent {
        let object = try JSONSerialization.jsonObject(with: data)
        try rejectUnsafeFields(in: object)

        let decoder = JSONDecoder()
        return try decoder.decode(TokenUsageEvent.self, from: data)
    }

    static func eventData(_ event: TokenUsageEvent) throws -> Data {
        try event.validate()
        return try jsonEncoder.encode(event)
    }

    static func envelopeData(events: [TokenUsageEvent]) throws -> Data {
        for event in events {
            try event.validate()
        }

        return try jsonEncoder.encode(TokenUsageEventEnvelope(
            schemaVersion: 1,
            source: "spill_local_app",
            events: events
        ))
    }

    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static func rejectUnsafeFields(in object: Any) throws {
        guard let dictionary = object as? [String: Any] else {
            throw TokenUsageValidationError.notJSONObject
        }

        let forbidden = forbiddenKeyPaths(in: dictionary)
        if !forbidden.isEmpty {
            throw TokenUsageValidationError.forbiddenFieldPresent(forbidden)
        }

        let unknownTopLevel = Set(dictionary.keys).subtracting(safeEventKeys)
        if !unknownTopLevel.isEmpty {
            throw TokenUsageValidationError.unknownFieldPresent(unknownTopLevel.sorted())
        }

        if let breakdown = dictionary["token_breakdown"] as? [String: Any] {
            let unknownBreakdown = Set(breakdown.keys).subtracting(safeBreakdownKeys)
            if !unknownBreakdown.isEmpty {
                throw TokenUsageValidationError.unknownFieldPresent(
                    unknownBreakdown.map { "token_breakdown.\($0)" }.sorted()
                )
            }
        }
    }

    private static func forbiddenKeyPaths(in value: Any, prefix: String = "") -> [String] {
        guard let dictionary = value as? [String: Any] else {
            return []
        }

        return dictionary.flatMap { key, child -> [String] in
            let path = prefix.isEmpty ? key : "\(prefix).\(key)"
            let current = forbiddenKeys.contains(key) ? [path] : []
            return current + forbiddenKeyPaths(in: child, prefix: path)
        }
    }
}
