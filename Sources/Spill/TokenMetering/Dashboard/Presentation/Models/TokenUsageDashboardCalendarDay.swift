import Foundation

struct TokenUsageDashboardCalendarDay: Identifiable, Equatable {
    let id: String
    let day: Int
    let title: String
    let detail: String
    let ratio: Double
    let isCurrentMonth: Bool
    let hasEvents: Bool
    let isPlaceholder: Bool
    let isToday: Bool
    let isSelected: Bool
}
