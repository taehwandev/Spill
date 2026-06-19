import Foundation

struct TokenUsageDashboardPeriodFilter: Identifiable, Equatable {
    let period: TokenUsageDashboardPeriod
    let title: String
    let detail: String
    let isSelected: Bool

    var id: String {
        period.rawValue
    }
}
