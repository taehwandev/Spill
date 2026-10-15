import Foundation

/// Observed percentage movement for one limit on one local calendar day.
/// The first reading establishes a baseline; consumption is added only when
/// later readings prove a change, including a new window after a reset.
struct TokenUsageDailyLimitUsage: Codable, Equatable, Sendable {
    let bucketKey: String
    let aiTool: TokenUsageAITool
    let limitKey: String
    var label: String
    let startPercent: Double
    var endPercent: Double
    var peakPercent: Double
    var consumedDeltaPercent: Double
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case bucketKey = "bucket_key"
        case aiTool = "ai_tool"
        case limitKey = "limit_key"
        case label
        case startPercent = "start_percent"
        case endPercent = "end_percent"
        case peakPercent = "peak_percent"
        case consumedDeltaPercent = "consumed_delta_percent"
        case updatedAt = "updated_at"
    }
}
