import Foundation

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

struct TokenUsageEvent: Codable, Equatable, Identifiable, Sendable {
    let schemaVersion: Int
    let deviceID: String
    let projectID: String
    let artifactID: String
    let runID: String
    let spanID: String
    let aiTool: TokenUsageAITool
    let taskType: TokenUsageTaskType
    let stage: TokenUsageStage
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let tokenBreakdown: TokenUsageBreakdown
    let latencyMS: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case deviceID = "device_id"
        case projectID = "project_id"
        case artifactID = "artifact_id"
        case runID = "run_id"
        case spanID = "span_id"
        case aiTool = "ai_tool"
        case taskType = "task_type"
        case stage
        case model
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
        case tokenBreakdown = "token_breakdown"
        case latencyMS = "latency_ms"
        case createdAt = "created_at"
    }

    var id: String {
        spanID
    }

    init(
        schemaVersion: Int,
        deviceID: String,
        projectID: String,
        artifactID: String,
        runID: String,
        spanID: String,
        aiTool: TokenUsageAITool = .unknown,
        taskType: TokenUsageTaskType,
        stage: TokenUsageStage,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        tokenBreakdown: TokenUsageBreakdown,
        latencyMS: Int,
        createdAt: String
    ) {
        self.schemaVersion = schemaVersion
        self.deviceID = deviceID
        self.projectID = projectID
        self.artifactID = artifactID
        self.runID = runID
        self.spanID = spanID
        self.aiTool = aiTool
        self.taskType = taskType
        self.stage = stage
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.tokenBreakdown = tokenBreakdown
        self.latencyMS = latencyMS
        self.createdAt = createdAt
    }
}

extension TokenUsageEvent {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        deviceID = try container.decode(String.self, forKey: .deviceID)
        projectID = try container.decode(String.self, forKey: .projectID)
        artifactID = try container.decode(String.self, forKey: .artifactID)
        runID = try container.decode(String.self, forKey: .runID)
        spanID = try container.decode(String.self, forKey: .spanID)
        aiTool = try container.decodeIfPresent(TokenUsageAITool.self, forKey: .aiTool) ?? .unknown
        taskType = try container.decode(TokenUsageTaskType.self, forKey: .taskType)
        stage = try container.decode(TokenUsageStage.self, forKey: .stage)
        model = try container.decode(String.self, forKey: .model)
        inputTokens = try container.decode(Int.self, forKey: .inputTokens)
        outputTokens = try container.decode(Int.self, forKey: .outputTokens)
        totalTokens = try container.decode(Int.self, forKey: .totalTokens)
        tokenBreakdown = try container.decode(TokenUsageBreakdown.self, forKey: .tokenBreakdown)
        latencyMS = try container.decode(Int.self, forKey: .latencyMS)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        try validate()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encode(projectID, forKey: .projectID)
        try container.encode(artifactID, forKey: .artifactID)
        try container.encode(runID, forKey: .runID)
        try container.encode(spanID, forKey: .spanID)
        try container.encode(aiTool, forKey: .aiTool)
        try container.encode(taskType, forKey: .taskType)
        try container.encode(stage, forKey: .stage)
        try container.encode(model, forKey: .model)
        try container.encode(inputTokens, forKey: .inputTokens)
        try container.encode(outputTokens, forKey: .outputTokens)
        try container.encode(totalTokens, forKey: .totalTokens)
        try container.encode(tokenBreakdown, forKey: .tokenBreakdown)
        try container.encode(latencyMS, forKey: .latencyMS)
        try container.encode(createdAt, forKey: .createdAt)
    }

    func validate() throws {
        guard schemaVersion == 1,
              Self.isOpaqueID(deviceID),
              Self.isOpaqueID(projectID),
              Self.isOpaqueID(artifactID),
              Self.isOpaqueID(runID),
              Self.isOpaqueID(spanID),
              taskType.isSafe,
              stage.isSafe,
              Self.isModelID(model),
              inputTokens >= 0,
              outputTokens >= 0,
              totalTokens >= 0,
              latencyMS >= 0,
              totalTokens == inputTokens + outputTokens,
              ISO8601DateFormatter.parseTokenUsageDate(from: createdAt) != nil
        else {
            throw TokenUsageValidationError.invalidRequiredField
        }

        try tokenBreakdown.validate()
        guard tokenBreakdown.total == totalTokens else {
            throw TokenUsageValidationError.invalidRequiredField
        }
    }

    private static func isOpaqueID(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9_-]{6,64}$"#, options: .regularExpression) != nil
    }

    private static func isModelID(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9_.:-]{2,80}$"#, options: .regularExpression) != nil
    }
}

enum TokenUsageWorkflowAssistance {
    static func isAssisted(_ event: TokenUsageEvent) -> Bool {
        event.taskType != .uncategorized || event.stage != .summarize
    }
}

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

enum TokenUsageValidationError: Error, Equatable {
    case notJSONObject
    case forbiddenFieldPresent([String])
    case unknownFieldPresent([String])
    case invalidRequiredField
}

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

extension ISO8601DateFormatter {
    static var tokenUsage: ISO8601DateFormatter {
        cachedTokenUsageFormatter(
            key: "app.spill.iso8601.tokenUsage.fractional",
            options: [.withInternetDateTime, .withFractionalSeconds]
        )
    }

    private static var tokenUsageWithoutFractionalSeconds: ISO8601DateFormatter {
        cachedTokenUsageFormatter(
            key: "app.spill.iso8601.tokenUsage.plain",
            options: [.withInternetDateTime]
        )
    }

    private static func cachedTokenUsageFormatter(
        key: String,
        options: ISO8601DateFormatter.Options
    ) -> ISO8601DateFormatter {
        if let formatter = Thread.current.threadDictionary[key] as? ISO8601DateFormatter {
            return formatter
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }

    static func parseTokenUsageDate(from string: String) -> Date? {
        fastTokenUsageDate(from: string)
            ?? tokenUsage.date(from: string)
            ?? tokenUsageWithoutFractionalSeconds.date(from: string)
    }

    private static func fastTokenUsageDate(from string: String) -> Date? {
        string.utf8.withContiguousStorageIfAvailable { bytes -> Date? in
            fastTokenUsageDate(from: bytes)
        } ?? fastTokenUsageDate(from: Array(string.utf8))
    }

    private static func fastTokenUsageDate(from bytes: [UInt8]) -> Date? {
        bytes.withUnsafeBufferPointer { buffer in
            fastTokenUsageDate(from: buffer)
        }
    }

    private static func fastTokenUsageDate(from bytes: UnsafeBufferPointer<UInt8>) -> Date? {
        guard bytes.count >= 20,
              bytes[4] == asciiDash,
              bytes[7] == asciiDash,
              bytes[10] == asciiT || bytes[10] == asciiLowercaseT,
              bytes[13] == asciiColon,
              bytes[16] == asciiColon
        else {
            return nil
        }

        guard let year = decimalValue(bytes, start: 0, count: 4),
              let month = decimalValue(bytes, start: 5, count: 2),
              let day = decimalValue(bytes, start: 8, count: 2),
              let hour = decimalValue(bytes, start: 11, count: 2),
              let minute = decimalValue(bytes, start: 14, count: 2),
              let second = decimalValue(bytes, start: 17, count: 2),
              (1...12).contains(month),
              (1...daysInMonth(year: year, month: month)).contains(day),
              (0...23).contains(hour),
              (0...59).contains(minute),
              (0...59).contains(second)
        else {
            return nil
        }

        var index = 19
        var fractionalSeconds = 0.0
        if index < bytes.count, bytes[index] == asciiPeriod {
            index += 1
            var value = 0
            var divisor = 1.0
            var parsedDigitCount = 0
            while index < bytes.count, let digit = decimalDigit(bytes[index]) {
                if parsedDigitCount < 9 {
                    value = (value * 10) + digit
                    divisor *= 10
                    parsedDigitCount += 1
                }
                index += 1
            }
            guard parsedDigitCount > 0 else {
                return nil
            }
            fractionalSeconds = Double(value) / divisor
        }

        let offsetSeconds: Int
        if index < bytes.count, bytes[index] == asciiZ || bytes[index] == asciiLowercaseZ {
            index += 1
            offsetSeconds = 0
        } else if index + 5 < bytes.count,
                  bytes[index] == asciiPlus || bytes[index] == asciiDash,
                  bytes[index + 3] == asciiColon,
                  let offsetHour = decimalValue(bytes, start: index + 1, count: 2),
                  let offsetMinute = decimalValue(bytes, start: index + 4, count: 2),
                  (0...23).contains(offsetHour),
                  (0...59).contains(offsetMinute) {
            let sign = bytes[index] == asciiPlus ? 1 : -1
            offsetSeconds = sign * ((offsetHour * 3_600) + (offsetMinute * 60))
            index += 6
        } else {
            return nil
        }

        guard index == bytes.count else {
            return nil
        }

        let days = daysSinceUnixEpoch(year: year, month: month, day: day)
        let wholeSeconds = (days * 86_400) + (hour * 3_600) + (minute * 60) + second - offsetSeconds
        return Date(timeIntervalSince1970: Double(wholeSeconds) + fractionalSeconds)
    }

    private static func decimalValue(
        _ bytes: UnsafeBufferPointer<UInt8>,
        start: Int,
        count: Int
    ) -> Int? {
        guard start >= 0, count > 0, start + count <= bytes.count else {
            return nil
        }

        var value = 0
        for index in start..<(start + count) {
            guard let digit = decimalDigit(bytes[index]) else {
                return nil
            }
            value = (value * 10) + digit
        }
        return value
    }

    private static func decimalDigit(_ byte: UInt8) -> Int? {
        guard byte >= asciiZero, byte <= asciiNine else {
            return nil
        }
        return Int(byte - asciiZero)
    }

    private static func daysSinceUnixEpoch(year: Int, month: Int, day: Int) -> Int {
        var adjustedYear = year
        adjustedYear -= month <= 2 ? 1 : 0
        let era = (adjustedYear >= 0 ? adjustedYear : adjustedYear - 399) / 400
        let yearOfEra = adjustedYear - (era * 400)
        let adjustedMonth = month + (month > 2 ? -3 : 9)
        let dayOfYear = ((153 * adjustedMonth) + 2) / 5 + day - 1
        let dayOfEra = (yearOfEra * 365) + (yearOfEra / 4) - (yearOfEra / 100) + dayOfYear
        return (era * 146_097) + dayOfEra - 719_468
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12:
            return 31
        case 4, 6, 9, 11:
            return 30
        case 2:
            return isLeapYear(year) ? 29 : 28
        default:
            return 0
        }
    }

    private static func isLeapYear(_ year: Int) -> Bool {
        year.isMultiple(of: 400) || (year.isMultiple(of: 4) && !year.isMultiple(of: 100))
    }

    private static let asciiZero = UInt8(ascii: "0")
    private static let asciiNine = UInt8(ascii: "9")
    private static let asciiDash = UInt8(ascii: "-")
    private static let asciiColon = UInt8(ascii: ":")
    private static let asciiPeriod = UInt8(ascii: ".")
    private static let asciiPlus = UInt8(ascii: "+")
    private static let asciiT = UInt8(ascii: "T")
    private static let asciiLowercaseT = UInt8(ascii: "t")
    private static let asciiZ = UInt8(ascii: "Z")
    private static let asciiLowercaseZ = UInt8(ascii: "z")
}
