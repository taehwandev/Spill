import Foundation

extension TokenUsageDashboardSnapshot {
    struct DateRange {
        let start: Date?
        let end: Date?
    }

    static func cutoffDateRange(
        for period: TokenUsageDashboardPeriod,
        periodOffset: Int,
        now: Date,
        calendar: Calendar
    ) -> DateRange {
        switch period {
        case .today:
            let todayStart = calendar.startOfDay(for: now)
            guard let targetStart = calendar.date(byAdding: .day, value: periodOffset, to: todayStart) else {
                return DateRange(start: todayStart, end: now)
            }
            let targetEnd = calendar.date(byAdding: .day, value: 1, to: targetStart) ?? now
            return DateRange(start: targetStart, end: targetEnd)
        case .sevenDays:
            let startOfToday = calendar.startOfDay(for: now)
            let daysToSubtract = 7 - 1
            guard let baseStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfToday) else {
                return DateRange(start: startOfToday, end: now)
            }
            guard let targetStart = calendar.date(byAdding: .day, value: periodOffset * 7, to: baseStart) else {
                return DateRange(start: baseStart, end: now)
            }
            let targetEnd = calendar.date(byAdding: .day, value: 7, to: targetStart) ?? now
            return DateRange(start: targetStart, end: targetEnd)
        case .thirtyDays:
            let startOfToday = calendar.startOfDay(for: now)
            let daysToSubtract = 30 - 1
            guard let baseStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfToday) else {
                return DateRange(start: startOfToday, end: now)
            }
            guard let targetStart = calendar.date(byAdding: .day, value: periodOffset * 30, to: baseStart) else {
                return DateRange(start: baseStart, end: now)
            }
            let targetEnd = calendar.date(byAdding: .day, value: 30, to: targetStart) ?? now
            return DateRange(start: targetStart, end: targetEnd)
        case .all:
            let nowYear = calendar.component(.year, from: now)
            let targetYear = nowYear + periodOffset
            var startComponents = DateComponents()
            startComponents.year = targetYear
            startComponents.month = 1
            startComponents.day = 1
            startComponents.hour = 0
            startComponents.minute = 0
            startComponents.second = 0
            guard let targetStart = calendar.date(from: startComponents) else {
                return DateRange(start: nil, end: nil)
            }
            var endComponents = DateComponents()
            endComponents.year = targetYear + 1
            endComponents.month = 1
            endComponents.day = 1
            endComponents.hour = 0
            endComponents.minute = 0
            endComponents.second = 0
            let targetEnd = calendar.date(from: endComponents) ?? now
            if periodOffset == 0 {
                return DateRange(start: targetStart, end: nil)
            }
            let resolvedEnd = targetEnd > now ? now : targetEnd
            return DateRange(start: targetStart, end: resolvedEnd)
        }
    }

    static func filterEvents(
        _ events: [TokenUsageEvent],
        selectedPeriod: TokenUsageDashboardPeriod,
        selectedCalendarDayID: String? = nil,
        now: Date,
        calendar: Calendar,
        periodOffset: Int = 0
    ) -> [TokenUsageEvent] {
        if let selectedCalendarDayID {
            return events.filter { event in
                localDayBucket(for: event.createdAt, calendar: calendar) == selectedCalendarDayID
            }
        }

        let range = cutoffDateRange(for: selectedPeriod, periodOffset: periodOffset, now: now, calendar: calendar)

        return events.filter { event in
            guard let createdAt = ISO8601DateFormatter.parseTokenUsageDate(from: event.createdAt) else {
                return false
            }
            if let start = range.start, createdAt < start {
                return false
            }
            if let end = range.end, createdAt >= end {
                return false
            }
            return true
        }
    }

    static func cutoffDate(
        for period: TokenUsageDashboardPeriod,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        switch period {
        case .today:
            return calendar.startOfDay(for: now)
        case .sevenDays:
            return periodStartDate(dayCount: 7, now: now, calendar: calendar)
        case .thirtyDays:
            return periodStartDate(dayCount: 30, now: now, calendar: calendar)
        case .all:
            return nil
        }
    }

    static func periodStartDate(
        dayCount: Int,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let todayStart = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(dayCount - 1), to: todayStart) ?? todayStart
    }

    static func filteredParsedEvents(
        _ events: [TokenUsageDashboardParsedEvent],
        selectedPeriod: TokenUsageDashboardPeriod,
        selectedCalendarDayID: String? = nil,
        now: Date,
        calendar: Calendar,
        periodOffset: Int = 0
    ) -> [TokenUsageDashboardParsedEvent] {
        if let selectedCalendarDayID {
            return events.filter { $0.dayBucket == selectedCalendarDayID }
        }

        let range = cutoffDateRange(for: selectedPeriod, periodOffset: periodOffset, now: now, calendar: calendar)

        return events.filter { event in
            guard let createdAt = event.createdAt else {
                return false
            }
            if let start = range.start, createdAt < start {
                return false
            }
            if let end = range.end, createdAt >= end {
                return false
            }
            return true
        }
    }

    static func localDayBucket(
        for createdAt: String,
        calendar: Calendar
    ) -> String {
        guard let date = ISO8601DateFormatter.parseTokenUsageDate(from: createdAt) else {
            return String(createdAt.prefix(10))
        }

        return dayID(for: date, calendar: calendar)
    }

    static func dayID(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day
        else {
            return String(ISO8601DateFormatter.tokenUsage.string(from: date).prefix(10))
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(forDayID dayID: String, calendar: Calendar) -> Date? {
        let parts = dayID
            .split(separator: "-")
            .compactMap { Int($0) }
        guard parts.count == 3 else {
            return nil
        }

        return calendar.date(from: DateComponents(
            calendar: calendar,
            year: parts[0],
            month: parts[1],
            day: parts[2]
        ))
    }

    static func calendarDays(
        events: [TokenUsageDashboardParsedEvent],
        monthStart: Date,
        selectedCalendarDayID: String?,
        todayCalendarDayID: String,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone,
        dayTokenTotals: [String: Int]? = nil
    ) -> [TokenUsageDashboardCalendarDay] {
        guard let displayEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }

        let resolvedDayTokenTotals: [String: Int]
        if let dayTokenTotals {
            resolvedDayTokenTotals = dayTokenTotals
        } else {
            let eventsByDay = Dictionary(grouping: events) { event in
                event.dayBucket
            }
            resolvedDayTokenTotals = eventsByDay.mapValues { groupedEvents in
                groupedEvents.reduce(0) { $0 + $1.event.totalTokens }
            }
        }
        let maxTokens = max(1, resolvedDayTokenTotals.values.max() ?? 0)

        let dayFormatter = cachedFixedDateFormatter(dateFormat: "d", locale: locale, timeZone: timeZone)
        let calendarDayTitleFormatter = cachedLocalizedDateFormatter(template: "MMM d", locale: locale, timeZone: timeZone)

        var days: [TokenUsageDashboardCalendarDay] = []
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingPlaceholderCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        let monthID = dayID(for: monthStart, calendar: calendar)
        for index in 0..<leadingPlaceholderCount {
            days.append(TokenUsageDashboardCalendarDay(
                id: "placeholder-leading-\(monthID)-\(index)",
                day: 0,
                title: "",
                detail: "",
                ratio: 0.0,
                isCurrentMonth: false,
                hasEvents: false,
                isPlaceholder: true,
                isToday: false,
                isSelected: false
            ))
        }

        var cursor = calendar.startOfDay(for: monthStart)
        while cursor < displayEnd {
            let dayBucket = dayID(for: cursor, calendar: calendar)
            let tokens = resolvedDayTokenTotals[dayBucket, default: 0]
            let day = calendar.component(.day, from: cursor)
            let calendarDayTitle = calendarDayTitleFormatter.string(from: cursor)
            days.append(TokenUsageDashboardCalendarDay(
                id: dayBucket,
                day: day,
                title: dayFormatter.string(from: cursor),
                detail: "\(calendarDayTitle) · \(formatTokens(tokens))",
                ratio: chartRatio(tokens: tokens, totalTokens: maxTokens),
                isCurrentMonth: true,
                hasEvents: tokens > 0,
                isPlaceholder: false,
                isToday: dayBucket == todayCalendarDayID,
                isSelected: dayBucket == selectedCalendarDayID
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        let trailingPlaceholderCount = (7 - (days.count % 7)) % 7
        for index in 0..<trailingPlaceholderCount {
            days.append(TokenUsageDashboardCalendarDay(
                id: "placeholder-trailing-\(monthID)-\(index)",
                day: 0,
                title: "",
                detail: "",
                ratio: 0.0,
                isCurrentMonth: false,
                hasEvents: false,
                isPlaceholder: true,
                isToday: false,
                isSelected: false
            ))
        }
        return days
    }

    static func normalizedCalendarMonthStart(
        events: [TokenUsageEvent],
        now: Date,
        proposedMonthStart: Date?,
        calendar: Calendar
    ) -> Date {
        let currentMonth = monthStart(for: now, calendar: calendar)
        let firstDataMonth = firstDataMonthStart(events: events, now: now, calendar: calendar)
        let proposed = proposedMonthStart.map { monthStart(for: $0, calendar: calendar) } ?? currentMonth
        if calendar.compare(proposed, to: firstDataMonth, toGranularity: .month) == .orderedAscending {
            return firstDataMonth
        }
        if calendar.compare(proposed, to: currentMonth, toGranularity: .month) == .orderedDescending {
            return currentMonth
        }
        return proposed
    }

    static func normalizedCalendarMonthStart(
        availableDateBounds: TokenUsageDashboardDateBounds?,
        now: Date,
        proposedMonthStart: Date?,
        calendar: Calendar
    ) -> Date {
        let currentMonth = monthStart(for: now, calendar: calendar)
        let firstDataMonth = availableDateBounds?.earliest
            .map { monthStart(for: $0, calendar: calendar) }
            ?? currentMonth
        let proposed = proposedMonthStart.map { monthStart(for: $0, calendar: calendar) } ?? currentMonth
        if calendar.compare(proposed, to: firstDataMonth, toGranularity: .month) == .orderedAscending {
            return firstDataMonth
        }
        if calendar.compare(proposed, to: currentMonth, toGranularity: .month) == .orderedDescending {
            return currentMonth
        }
        return proposed
    }

    static func normalizedCalendarMonthStart(
        events: [TokenUsageDashboardParsedEvent],
        availableDateBounds: TokenUsageDashboardDateBounds?,
        now: Date,
        proposedMonthStart: Date?,
        calendar: Calendar
    ) -> Date {
        let currentMonth = monthStart(for: now, calendar: calendar)
        let firstDataMonth = availableDateBounds?.earliest
            .map { monthStart(for: $0, calendar: calendar) }
            ?? firstDataMonthStart(events: events, now: now, calendar: calendar)
        let proposed = proposedMonthStart.map { monthStart(for: $0, calendar: calendar) } ?? currentMonth
        if calendar.compare(proposed, to: firstDataMonth, toGranularity: .month) == .orderedAscending {
            return firstDataMonth
        }
        if calendar.compare(proposed, to: currentMonth, toGranularity: .month) == .orderedDescending {
            return currentMonth
        }
        return proposed
    }

    static func monthStart(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
    }

    static func firstDataMonthStart(
        events: [TokenUsageEvent],
        now: Date,
        calendar: Calendar
    ) -> Date {
        events
            .compactMap { ISO8601DateFormatter.parseTokenUsageDate(from: $0.createdAt) }
            .min()
            .map { monthStart(for: $0, calendar: calendar) }
            ?? monthStart(for: now, calendar: calendar)
    }

    static func firstDataMonthStart(
        events: [TokenUsageDashboardParsedEvent],
        now: Date,
        calendar: Calendar
    ) -> Date {
        events
            .compactMap(\.createdAt)
            .min()
            .map { monthStart(for: $0, calendar: calendar) }
            ?? monthStart(for: now, calendar: calendar)
    }

    static func chartRatio(tokens: Int, totalTokens: Int) -> Double {
        guard tokens > 0, totalTokens > 0 else {
            return 0.0
        }

        let ratio = Double(tokens) / Double(totalTokens)
        guard ratio.isFinite else {
            return 0.0
        }
        return min(max(ratio, 0.0), 1.0)
    }
}
