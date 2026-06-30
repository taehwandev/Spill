import Foundation

struct PrivateUsageSharedSummary: Codable, Equatable, Sendable {
    static let currentSummaryVersion = 1

    let schemaVersion: Int
    let summaryVersion: Int
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

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case summaryVersion = "summary_version"
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
    }

    init(aggregate: PrivateUsageDailyAggregate) {
        schemaVersion = aggregate.schemaVersion
        summaryVersion = Self.currentSummaryVersion
        bucketKind = aggregate.bucketKind
        bucketKey = aggregate.bucketKey
        bucketStartAt = aggregate.bucketStartAt
        bucketEndAt = aggregate.bucketEndAt
        timezone = aggregate.timezone
        generatedAt = aggregate.generatedAt
        totals = aggregate.totals
        sourceTotals = aggregate.sourceTotals
        toolTotals = aggregate.toolTotals
        modelTotals = aggregate.modelTotals
        taskTypeTotals = aggregate.taskTypeTotals
        stageTotals = aggregate.stageTotals
        workflowUsageTotals = aggregate.workflowUsageTotals
    }

    func canonicalHash() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return PrivateUsageDailyBucketBuilder.sha256Hex(try encoder.encode(self))
    }
}
