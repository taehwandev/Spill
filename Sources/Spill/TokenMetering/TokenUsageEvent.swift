import Foundation

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
    let tokenAccounting: TokenUsageAccounting?
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
        tokenAccounting: TokenUsageAccounting? = nil,
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
        self.tokenAccounting = tokenAccounting
        self.latencyMS = latencyMS
        self.createdAt = createdAt
    }

    func withTokenAccounting(_ accounting: TokenUsageAccounting?) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: schemaVersion,
            deviceID: deviceID,
            projectID: projectID,
            artifactID: artifactID,
            runID: runID,
            spanID: spanID,
            aiTool: aiTool,
            taskType: taskType,
            stage: stage,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            tokenBreakdown: tokenBreakdown,
            tokenAccounting: accounting,
            latencyMS: latencyMS,
            createdAt: createdAt
        )
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
        tokenAccounting = nil
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
        try tokenAccounting?.validate(inputTokens: inputTokens, outputTokens: outputTokens)
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
