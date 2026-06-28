import Foundation

struct PrivateUsageDailyAggregate: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let bucketKind: String
    let bucketKey: String
    let bucketStartAt: String
    let bucketEndAt: String
    let timezone: String
    let generatedAt: String
    let totals: PrivateUsageTokenTotals
    let sourceTotals: [String: Int]
    let toolTotals: [String: PrivateUsageTokenTotals]
    let modelTotals: [String: PrivateUsageTokenTotals]
    let taskTypeTotals: [String: PrivateUsageTokenTotals]
    let stageTotals: [String: PrivateUsageTokenTotals]
    let workflowUsageTotals: PrivateUsageWorkflowUsageTotals
    let workItems: [PrivateUsageWorkItemAggregate]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case bucketKind = "bucket_kind"
        case bucketKey = "bucket_key"
        case bucketStartAt = "bucket_start_at"
        case bucketEndAt = "bucket_end_at"
        case timezone
        case generatedAt = "generated_at"
        case totals
        case sourceTotals = "source_totals"
        case toolTotals = "tool_totals"
        case modelTotals = "model_totals"
        case taskTypeTotals = "task_type_totals"
        case stageTotals = "stage_totals"
        case workflowUsageTotals = "workflow_usage_totals"
        case workItems = "work_items"
    }

    init(
        schemaVersion: Int,
        bucketKind: String,
        bucketKey: String,
        bucketStartAt: String,
        bucketEndAt: String,
        timezone: String,
        generatedAt: String,
        totals: PrivateUsageTokenTotals,
        sourceTotals: [String: Int],
        toolTotals: [String: PrivateUsageTokenTotals],
        modelTotals: [String: PrivateUsageTokenTotals],
        taskTypeTotals: [String: PrivateUsageTokenTotals],
        stageTotals: [String: PrivateUsageTokenTotals],
        workflowUsageTotals: PrivateUsageWorkflowUsageTotals,
        workItems: [PrivateUsageWorkItemAggregate] = []
    ) {
        self.schemaVersion = schemaVersion
        self.bucketKind = bucketKind
        self.bucketKey = bucketKey
        self.bucketStartAt = bucketStartAt
        self.bucketEndAt = bucketEndAt
        self.timezone = timezone
        self.generatedAt = generatedAt
        self.totals = totals
        self.sourceTotals = sourceTotals
        self.toolTotals = toolTotals
        self.modelTotals = modelTotals
        self.taskTypeTotals = taskTypeTotals
        self.stageTotals = stageTotals
        self.workflowUsageTotals = workflowUsageTotals
        self.workItems = workItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        bucketKind = try container.decode(String.self, forKey: .bucketKind)
        bucketKey = try container.decode(String.self, forKey: .bucketKey)
        bucketStartAt = try container.decode(String.self, forKey: .bucketStartAt)
        bucketEndAt = try container.decode(String.self, forKey: .bucketEndAt)
        timezone = try container.decode(String.self, forKey: .timezone)
        generatedAt = try container.decode(String.self, forKey: .generatedAt)
        totals = try container.decode(PrivateUsageTokenTotals.self, forKey: .totals)
        sourceTotals = try container.decode([String: Int].self, forKey: .sourceTotals)
        toolTotals = try container.decode([String: PrivateUsageTokenTotals].self, forKey: .toolTotals)
        modelTotals = try container.decode([String: PrivateUsageTokenTotals].self, forKey: .modelTotals)
        taskTypeTotals = try container.decode([String: PrivateUsageTokenTotals].self, forKey: .taskTypeTotals)
        stageTotals = try container.decode([String: PrivateUsageTokenTotals].self, forKey: .stageTotals)
        workflowUsageTotals = try container.decodeIfPresent(
            PrivateUsageWorkflowUsageTotals.self,
            forKey: .workflowUsageTotals
        ) ?? .zero
        workItems = try container.decodeIfPresent(
            [PrivateUsageWorkItemAggregate].self,
            forKey: .workItems
        ) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(bucketKind, forKey: .bucketKind)
        try container.encode(bucketKey, forKey: .bucketKey)
        try container.encode(bucketStartAt, forKey: .bucketStartAt)
        try container.encode(bucketEndAt, forKey: .bucketEndAt)
        try container.encode(timezone, forKey: .timezone)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(totals, forKey: .totals)
        try container.encode(sourceTotals, forKey: .sourceTotals)
        try container.encode(toolTotals, forKey: .toolTotals)
        try container.encode(modelTotals, forKey: .modelTotals)
        try container.encode(taskTypeTotals, forKey: .taskTypeTotals)
        try container.encode(stageTotals, forKey: .stageTotals)
        try container.encode(workflowUsageTotals, forKey: .workflowUsageTotals)
        try container.encode(workItems, forKey: .workItems)
    }
}
