import Foundation

struct TokenUsageDashboardTrendBucket: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let value: String
    let eventCount: Int
    let totalTokens: Int
    let ratio: Double
    let hasEvents: Bool
    let toolRows: [TokenUsageDashboardBarRow]
}
