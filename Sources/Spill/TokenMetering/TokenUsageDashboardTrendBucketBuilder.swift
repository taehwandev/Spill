import Foundation

struct TokenUsageDashboardTrendBucket: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let ratio: Double
    let hasEvents: Bool
}

enum TokenUsageDashboardTrendBucketBuilder {
    static func buckets(
        events: [TokenUsageEvent],
        selectedPeriod: TokenUsageDashboardPeriod,
        now: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> [TokenUsageDashboardTrendBucket] {
        switch selectedPeriod {
        case .today:
            return []
        case .sevenDays:
            return dailyBuckets(
                events: events,
                dayCount: 7,
                now: now,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            )
        case .thirtyDays:
            return dailyBuckets(
                events: events,
                dayCount: 30,
                now: now,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            )
        case .all:
            return monthlyBuckets(
                events: events,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            )
        }
    }

    private static func dailyBuckets(
        events: [TokenUsageEvent],
        dayCount: Int,
        now: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> [TokenUsageDashboardTrendBucket] {
        let start = TokenUsageDashboardSnapshot.periodStartDate(
            dayCount: dayCount,
            now: now,
            calendar: calendar
        )
        let eventsByDay = Dictionary(grouping: events) { event in
            dayID(for: event.createdAt, calendar: calendar)
        }
        let maxTokens = max(1, eventsByDay.values.map { groupedEvents in
            groupedEvents.reduce(0) { $0 + $1.totalTokens }
        }.max() ?? 0)

        let titleFormatter = DateFormatter()
        titleFormatter.locale = locale
        titleFormatter.timeZone = timeZone
        titleFormatter.dateFormat = dayCount <= 7 ? "M/d" : "d"

        let detailFormatter = DateFormatter()
        detailFormatter.locale = locale
        detailFormatter.timeZone = timeZone
        detailFormatter.setLocalizedDateFormatFromTemplate("MMM d")

        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }

            let bucketID = TokenUsageDashboardSnapshot.dayID(for: day, calendar: calendar)
            let groupedEvents = eventsByDay[bucketID, default: []]
            let tokens = groupedEvents.reduce(0) { $0 + $1.totalTokens }
            let dateTitle = detailFormatter.string(from: day)
            return TokenUsageDashboardTrendBucket(
                id: bucketID,
                title: titleFormatter.string(from: day),
                detail: "\(dateTitle) · \(TokenUsageDashboardSnapshot.formatTokens(tokens))",
                ratio: TokenUsageDashboardSnapshot.chartRatio(tokens: tokens, totalTokens: maxTokens),
                hasEvents: !groupedEvents.isEmpty
            )
        }
    }

    private static func monthlyBuckets(
        events: [TokenUsageEvent],
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> [TokenUsageDashboardTrendBucket] {
        let datedEvents = events.compactMap { event -> (event: TokenUsageEvent, date: Date)? in
            guard let date = ISO8601DateFormatter.parseTokenUsageDate(from: event.createdAt) else {
                return nil
            }
            return (event, date)
        }
        guard let firstDate = datedEvents.map(\.date).min(),
              let lastDate = datedEvents.map(\.date).max()
        else {
            return []
        }

        let startMonth = monthStart(for: firstDate, calendar: calendar)
        let endMonth = monthStart(for: lastDate, calendar: calendar)
        let eventsByMonth = Dictionary(grouping: datedEvents) { item in
            monthID(for: item.date, calendar: calendar)
        }
        let maxTokens = max(1, eventsByMonth.values.map { groupedEvents in
            groupedEvents.reduce(0) { $0 + $1.event.totalTokens }
        }.max() ?? 0)

        let sameYear = calendar.component(.year, from: startMonth) == calendar.component(.year, from: endMonth)
        let titleFormatter = DateFormatter()
        titleFormatter.locale = locale
        titleFormatter.timeZone = timeZone
        titleFormatter.setLocalizedDateFormatFromTemplate(sameYear ? "MMM" : "MMM yy")

        let detailFormatter = DateFormatter()
        detailFormatter.locale = locale
        detailFormatter.timeZone = timeZone
        detailFormatter.setLocalizedDateFormatFromTemplate("y MMM")

        var buckets: [TokenUsageDashboardTrendBucket] = []
        var cursor = startMonth
        while calendar.compare(cursor, to: endMonth, toGranularity: .month) != .orderedDescending {
            let bucketID = monthID(for: cursor, calendar: calendar)
            let groupedEvents = eventsByMonth[bucketID, default: []]
            let tokens = groupedEvents.reduce(0) { $0 + $1.event.totalTokens }
            let dateTitle = detailFormatter.string(from: cursor)
            buckets.append(TokenUsageDashboardTrendBucket(
                id: bucketID,
                title: titleFormatter.string(from: cursor),
                detail: "\(dateTitle) · \(TokenUsageDashboardSnapshot.formatTokens(tokens))",
                ratio: TokenUsageDashboardSnapshot.chartRatio(tokens: tokens, totalTokens: maxTokens),
                hasEvents: !groupedEvents.isEmpty
            ))

            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return buckets
    }

    private static func dayID(for createdAt: String, calendar: Calendar) -> String {
        guard let date = ISO8601DateFormatter.parseTokenUsageDate(from: createdAt) else {
            return String(createdAt.prefix(10))
        }

        return TokenUsageDashboardSnapshot.dayID(for: date, calendar: calendar)
    }

    private static func monthStart(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private static func monthID(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year,
              let month = components.month
        else {
            return String(ISO8601DateFormatter.tokenUsage.string(from: date).prefix(7))
        }

        return String(format: "%04d-%02d", year, month)
    }
}
