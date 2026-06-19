import Foundation

struct TokenUsageDashboardParsedEvent {
    let event: TokenUsageEvent
    let createdAt: Date?
    let dayBucket: String
    let monthBucket: String

    init(event: TokenUsageEvent, calendar: Calendar) {
        self.event = event
        let parsedDate = ISO8601DateFormatter.parseTokenUsageDate(from: event.createdAt)
        self.createdAt = parsedDate
        self.dayBucket = parsedDate.map {
            TokenUsageDashboardSnapshot.dayID(for: $0, calendar: calendar)
        } ?? String(event.createdAt.prefix(10))
        self.monthBucket = parsedDate.map { date in
            let components = calendar.dateComponents([.year, .month], from: date)
            guard let year = components.year, let month = components.month else {
                return String(event.createdAt.prefix(7))
            }
            return String(format: "%04d-%02d", year, month)
        } ?? String(event.createdAt.prefix(7))
    }
}
