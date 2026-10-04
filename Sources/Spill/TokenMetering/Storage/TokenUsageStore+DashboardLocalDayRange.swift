import Foundation

extension TokenUsageStore {
    /// Exact half-open range contained in one local day. Grouping such a range
    /// needs no per-event UTC slice: every timestamp belongs to the same bucket.
    static func isSingleDashboardCalendarDay(
        startingAt start: Date?, endingBefore end: Date?, calendar: Calendar
    ) -> Bool {
        guard let start, let end, start < end,
              let followingDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start))
        else { return false }
        return end <= calendar.startOfDay(for: followingDay)
    }
}
