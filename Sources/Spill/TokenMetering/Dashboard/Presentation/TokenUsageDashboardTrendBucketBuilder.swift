import Foundation

enum TokenUsageDashboardTrendBucketBuilder {
}

extension TokenUsageDashboardTrendBucketBuilder {
    static func buckets(
        events: [TokenUsageDashboardParsedEvent],
        selectedPeriod: TokenUsageDashboardPeriod,
        language: TokenMeteringLanguage,
        now: Date,
        periodOffset: Int = 0,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> [TokenUsageDashboardTrendBucket] {
        switch selectedPeriod {
        case .today:
            return []
        case .sevenDays:
            return dailyBuckets(
                events: events,
                dayCount: 7,
                language: language,
                now: now,
                periodOffset: periodOffset,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone,
                visibleTools: visibleTools
            )
        case .thirtyDays:
            return dailyBuckets(
                events: events,
                dayCount: 30,
                language: language,
                now: now,
                periodOffset: periodOffset,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone,
                visibleTools: visibleTools
            )
        case .all:
            return monthlyBuckets(
                events: events,
                language: language,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone,
                visibleTools: visibleTools
            )
        }
    }

}

private extension TokenUsageDashboardTrendBucketBuilder {
    private static func dailyBuckets(
        events: [TokenUsageDashboardParsedEvent],
        dayCount: Int,
        language: TokenMeteringLanguage,
        now: Date,
        periodOffset: Int = 0,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone,
        visibleTools: Set<TokenUsageAITool>?
    ) -> [TokenUsageDashboardTrendBucket] {
        let baseStart = TokenUsageDashboardSnapshot.periodStartDate(
            dayCount: dayCount,
            now: now,
            calendar: calendar
        )
        let start = calendar.date(byAdding: .day, value: periodOffset * dayCount, to: baseStart) ?? baseStart
        let summariesByDay = Self.summariesByBucket(
            events: events,
            language: language,
            visibleTools: visibleTools,
            bucketID: \.dayBucket
        )
        let maxTokens = max(1, summariesByDay.values.map(\.totalTokens).max() ?? 0)

        let titleFormatter = TokenUsageDashboardSnapshot.cachedFixedDateFormatter(
            dateFormat: dayCount <= 7 ? "M/d" : "d",
            locale: locale,
            timeZone: timeZone
        )
        let detailFormatter = TokenUsageDashboardSnapshot.cachedLocalizedDateFormatter(
            template: "MMM d",
            locale: locale,
            timeZone: timeZone
        )

        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }

            let bucketID = TokenUsageDashboardSnapshot.dayID(for: day, calendar: calendar)
            let summary = summariesByDay[bucketID, default: BucketSummary.empty]
            let dateTitle = detailFormatter.string(from: day)
            return TokenUsageDashboardTrendBucket(
                id: bucketID,
                title: titleFormatter.string(from: day),
                detail: "\(dateTitle) · \(TokenUsageDashboardSnapshot.formatTokens(summary.totalTokens))",
                value: TokenUsageDashboardSnapshot.formatTokens(summary.totalTokens),
                eventCount: summary.eventCount,
                totalTokens: summary.totalTokens,
                ratio: TokenUsageDashboardSnapshot.chartRatio(tokens: summary.totalTokens, totalTokens: maxTokens),
                hasEvents: summary.eventCount > 0,
                toolRows: summary.toolRows
            )
        }
    }

}

private extension TokenUsageDashboardTrendBucketBuilder {
    private static func monthlyBuckets(
        events: [TokenUsageDashboardParsedEvent],
        language: TokenMeteringLanguage,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone,
        visibleTools: Set<TokenUsageAITool>?
    ) -> [TokenUsageDashboardTrendBucket] {
        var datedEvents: [TokenUsageDashboardParsedEvent] = []
        var firstDate: Date?
        var lastDate: Date?
        for event in events {
            guard let createdAt = event.createdAt else {
                continue
            }
            datedEvents.append(event)
            firstDate = firstDate.map { Swift.min($0, createdAt) } ?? createdAt
            lastDate = lastDate.map { Swift.max($0, createdAt) } ?? createdAt
        }

        guard let firstDate,
              let lastDate
        else {
            return []
        }

        let startMonth = monthStart(for: firstDate, calendar: calendar)
        let endMonth = monthStart(for: lastDate, calendar: calendar)
        let summariesByMonth = Self.summariesByBucket(
            events: datedEvents,
            language: language,
            visibleTools: visibleTools,
            bucketID: \.monthBucket
        )
        let maxTokens = max(1, summariesByMonth.values.map(\.totalTokens).max() ?? 0)

        let sameYear = calendar.component(.year, from: startMonth) == calendar.component(.year, from: endMonth)
        let titleFormatter = TokenUsageDashboardSnapshot.cachedLocalizedDateFormatter(
            template: sameYear ? "MMM" : "MMM yy",
            locale: locale,
            timeZone: timeZone
        )
        let detailFormatter = TokenUsageDashboardSnapshot.cachedLocalizedDateFormatter(
            template: "y MMM",
            locale: locale,
            timeZone: timeZone
        )

        var buckets: [TokenUsageDashboardTrendBucket] = []
        var cursor = startMonth
        while calendar.compare(cursor, to: endMonth, toGranularity: .month) != .orderedDescending {
            let bucketID = monthID(for: cursor, calendar: calendar)
            let summary = summariesByMonth[bucketID, default: BucketSummary.empty]
            let dateTitle = detailFormatter.string(from: cursor)
            buckets.append(TokenUsageDashboardTrendBucket(
                id: bucketID,
                title: titleFormatter.string(from: cursor),
                detail: "\(dateTitle) · \(TokenUsageDashboardSnapshot.formatTokens(summary.totalTokens))",
                value: TokenUsageDashboardSnapshot.formatTokens(summary.totalTokens),
                eventCount: summary.eventCount,
                totalTokens: summary.totalTokens,
                ratio: TokenUsageDashboardSnapshot.chartRatio(tokens: summary.totalTokens, totalTokens: maxTokens),
                hasEvents: summary.eventCount > 0,
                toolRows: summary.toolRows
            ))

            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return buckets
    }

}

private extension TokenUsageDashboardTrendBucketBuilder {
    private static func summariesByBucket<BucketID: Hashable>(
        events: [TokenUsageDashboardParsedEvent],
        language: TokenMeteringLanguage,
        visibleTools: Set<TokenUsageAITool>?,
        bucketID: (TokenUsageDashboardParsedEvent) -> BucketID
    ) -> [BucketID: BucketSummary] {
        var summaries = [BucketID: BucketSummary]()
        for event in events {
            summaries[bucketID(event), default: BucketSummary.empty].add(event)
        }
        return summaries.mapValues { summary in
            var summary = summary
            summary.finalizeToolRows(language: language, visibleTools: visibleTools)
            return summary
        }
    }

}

private extension TokenUsageDashboardTrendBucketBuilder {
    private struct BucketSummary {
        var eventCount = 0
        var totalTokens = 0
        private var toolTotals = [TokenUsageAITool: Int]()
        var toolRows: [TokenUsageDashboardBarRow] = []

        static let empty = BucketSummary()

        mutating func add(_ parsedEvent: TokenUsageDashboardParsedEvent) {
            let event = parsedEvent.event
            eventCount += 1
            totalTokens += event.totalTokens
            toolTotals[event.aiTool, default: 0] += event.totalTokens
        }

        mutating func finalizeToolRows(language: TokenMeteringLanguage, visibleTools: Set<TokenUsageAITool>?) {
            let visibleToolTotals = toolTotals.filter { tool, _ in
                visibleTools?.contains(tool) ?? true
            }
            toolRows = TokenUsageDashboardRowBuilder.rows(
                tokenValues: visibleToolTotals,
                totalTokens: totalTokens,
                id: { $0.rawValue },
                label: { $0.dashboardLabel(language: language) }
            )
        }
    }

}

private extension TokenUsageDashboardTrendBucketBuilder {
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
