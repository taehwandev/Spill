import Foundation

enum TokenUsageDisplayMode: String, CaseIterable, Identifiable {
    case tokens = "Tokens"
    case percentage = "Share %"

    var id: String { rawValue }

    var localizedTitle: String {
        localizedTitle(language: .current())
    }

    func localizedTitle(language: TokenMeteringLanguage) -> String {
        switch self {
        case .tokens:
            return TokenMeteringL10n.text(.displayModeTokens, language: language)
        case .percentage:
            return TokenMeteringL10n.text(.displayModeShare, language: language)
        }
    }
}

struct TokenMeteringModeStatus: Identifiable, Equatable {
    let id: String
    let title: String
    let state: String
    let detail: String
    let isActive: Bool
}

struct TokenUsageDashboardKPI: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let detail: String
}

struct TokenUsageDashboardBarRow: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let ratio: Double
}

struct TokenUsageDashboardSessionRow: Identifiable, Equatable {
    let id: String
    let runID: String
    let title: String
    let value: String
    let detail: String
    let eventCount: Int
}

struct TokenUsageDashboardCalendarDay: Identifiable, Equatable {
    let id: String
    let day: Int
    let title: String
    let detail: String
    let ratio: Double
    let isCurrentMonth: Bool
    let hasEvents: Bool
    let isPlaceholder: Bool
}

struct TokenUsageDashboardToolFilter: Identifiable, Equatable {
    let tool: TokenUsageAITool?
    let title: String
    let detail: String
    let isSelected: Bool

    var id: String {
        tool?.rawValue ?? "all"
    }
}

enum TokenUsageDashboardPeriod: String, CaseIterable, Equatable {
    case today
    case sevenDays
    case thirtyDays
    case all

    var title: String {
        title(language: .current())
    }

    func title(language: TokenMeteringLanguage) -> String {
        switch self {
        case .today:
            return TokenMeteringL10n.text(.periodToday, language: language)
        case .sevenDays:
            return TokenMeteringL10n.text(.periodSevenDays, language: language)
        case .thirtyDays:
            return TokenMeteringL10n.text(.periodThirtyDays, language: language)
        case .all:
            return TokenMeteringL10n.text(.periodAll, language: language)
        }
    }
}

struct TokenUsageDashboardPeriodFilter: Identifiable, Equatable {
    let period: TokenUsageDashboardPeriod
    let title: String
    let detail: String
    let isSelected: Bool

    var id: String {
        period.rawValue
    }
}

struct TokenUsageSelfTestMessage: Equatable {
    let text: String
    let isSuccess: Bool
}

struct TokenUsageDashboardSnapshot: Equatable {
    let eventCount: Int
    let totalTokens: Int
    let displayMode: TokenUsageDisplayMode
    let kpis: [TokenUsageDashboardKPI]
    let periodFilters: [TokenUsageDashboardPeriodFilter]
    let toolFilters: [TokenUsageDashboardToolFilter]
    let toolRows: [TokenUsageDashboardBarRow]
    let modelRows: [TokenUsageDashboardBarRow]
    let taskRows: [TokenUsageDashboardBarRow]
    let stageRows: [TokenUsageDashboardBarRow]
    let sourceRows: [TokenUsageDashboardBarRow]
    let sessions: [TokenUsageDashboardSessionRow]
    let selectedSession: TokenUsageDashboardSessionRow?
    let calendarDays: [TokenUsageDashboardCalendarDay]
    let calendarMonthTitle: String
    let calendarWeekdayTitles: [String]
    let canNavigatePreviousCalendarMonth: Bool
    let canNavigateNextCalendarMonth: Bool
    let codexLastUpdated: Date?
    let claudeLastUpdated: Date?
    let antigravityLastUpdated: Date?
    let overallLastUpdated: Date?
    let codexLastUpdatedString: String?
    let claudeLastUpdatedString: String?
    let antigravityLastUpdatedString: String?
    let overallLastUpdatedString: String?

    init(
        events: [TokenUsageEvent],
        selectedTool: TokenUsageAITool? = nil,
        selectedPeriod: TokenUsageDashboardPeriod = .all,
        selectedSessionID: String? = nil,
        displayMode: TokenUsageDisplayMode = .tokens,
        language: TokenMeteringLanguage = .current(),
        now: Date = Date(),
        calendarMonthStart: Date? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.displayMode = displayMode
        let dashboardEvents = events.filter { $0.aiTool.isDashboardTool }

        codexLastUpdated = dashboardEvents
            .filter { $0.aiTool == .codex }
            .compactMap { ISO8601DateFormatter.parseTokenUsageDate(from: $0.createdAt) }
            .max()
        claudeLastUpdated = dashboardEvents
            .filter { $0.aiTool == .claude }
            .compactMap { ISO8601DateFormatter.parseTokenUsageDate(from: $0.createdAt) }
            .max()
        antigravityLastUpdated = dashboardEvents
            .filter { $0.aiTool == .antigravity }
            .compactMap { ISO8601DateFormatter.parseTokenUsageDate(from: $0.createdAt) }
            .max()
        overallLastUpdated = dashboardEvents
            .compactMap { ISO8601DateFormatter.parseTokenUsageDate(from: $0.createdAt) }
            .max()

        let selectedDashboardTool = selectedTool.flatMap { tool in
            tool.isDashboardTool ? tool : nil
        }
        let periodEvents = Self.filterEvents(
            dashboardEvents,
            selectedPeriod: selectedPeriod,
            now: now,
            calendar: calendar
        )
        let visibleEvents = selectedDashboardTool.map { tool in
            periodEvents.filter { $0.aiTool == tool }
        } ?? periodEvents
        let sessionRows = Self.sessionRows(
            events: visibleEvents,
            displayMode: displayMode,
            totalTokens: visibleEvents.reduce(0) { $0 + $1.totalTokens },
            language: language,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )
        let selectedSessionRow = selectedSessionID.flatMap { id in
            sessionRows.first { $0.id == id }
        }
        let focusedEvents = selectedSessionRow.map { session in
            visibleEvents.filter {
                Self.workItemID(for: $0, calendar: calendar) == session.id
            }
        } ?? visibleEvents

        eventCount = focusedEvents.count
        let capturedTotalTokens = focusedEvents.reduce(0) { $0 + $1.totalTokens }
        totalTokens = capturedTotalTokens
        let visibleCapturedToolTokens = Self.toolTotals(events: focusedEvents)

        periodFilters = TokenUsageDashboardPeriod.allCases.map { period in
            let periodCapturedEvents = Self.filterEvents(
                dashboardEvents,
                selectedPeriod: period,
                now: now,
                calendar: calendar
            )
            let capturedPeriodTotal = periodCapturedEvents.reduce(0) { $0 + $1.totalTokens }
            return TokenUsageDashboardPeriodFilter(
                period: period,
                title: period.title(language: language),
                detail: Self.formatTokens(capturedPeriodTotal),
                isSelected: selectedPeriod == period
            )
        }

        let allToolTotals = Self.toolTotals(events: periodEvents)
        toolFilters = Self.toolFilters(
            selectedTool: selectedDashboardTool,
            totals: allToolTotals,
            totalEvents: periodEvents.count,
            language: language
        )

        let inputTokens = focusedEvents.reduce(0) { $0 + $1.inputTokens }
        let outputTokens = focusedEvents.reduce(0) { $0 + $1.outputTokens }
        let latencySamples = focusedEvents.map(\.latencyMS).filter { $0 > 0 }
        let averageLatency = latencySamples.isEmpty
            ? nil
            : latencySamples.reduce(0, +) / latencySamples.count

        switch displayMode {
        case .tokens:
            kpis = [
                TokenUsageDashboardKPI(
                    id: "total",
                    title: TokenMeteringL10n.text(.totalTokens, language: language),
                    value: Self.formatTokens(totalTokens),
                    detail: TokenMeteringL10n.localEventsDetail(eventCount: focusedEvents.count, language: language)
                ),
                TokenUsageDashboardKPI(
                    id: "input",
                    title: TokenMeteringL10n.text(.input, language: language),
                    value: Self.formatTokens(inputTokens),
                    detail: Self.percentageDetail(value: inputTokens, total: totalTokens, language: language)
                ),
                TokenUsageDashboardKPI(
                    id: "output",
                    title: TokenMeteringL10n.text(.output, language: language),
                    value: Self.formatTokens(outputTokens),
                    detail: Self.percentageDetail(value: outputTokens, total: totalTokens, language: language)
                ),
                TokenUsageDashboardKPI(
                    id: "latency",
                    title: TokenMeteringL10n.text(.avgLatency, language: language),
                    value: averageLatency.map { "\($0) ms" } ?? TokenMeteringL10n.text(.latencyUnavailable, language: language),
                    detail: averageLatency == nil
                        ? TokenMeteringL10n.text(.runtimeTimingUnavailable, language: language)
                        : TokenMeteringL10n.text(.perLocalSpan, language: language)
                )
            ]
        case .percentage:
            let totalPercent = totalTokens > 0 ? 100.0 : 0.0
            let inputPercent = totalTokens > 0 ? (Double(inputTokens) / Double(totalTokens)) * 100.0 : 0.0
            let outputPercent = totalTokens > 0 ? (Double(outputTokens) / Double(totalTokens)) * 100.0 : 0.0
            kpis = [
                TokenUsageDashboardKPI(
                    id: "total",
                    title: TokenMeteringL10n.text(.totalShare, language: language),
                    value: Self.formatPercentage(totalPercent),
                    detail: TokenMeteringL10n.localEventsDetail(eventCount: focusedEvents.count, language: language)
                ),
                TokenUsageDashboardKPI(
                    id: "input",
                    title: TokenMeteringL10n.text(.inputShare, language: language),
                    value: Self.formatPercentage(inputPercent),
                    detail: TokenMeteringL10n.tokenCountDetail(Self.formatTokens(inputTokens), language: language)
                ),
                TokenUsageDashboardKPI(
                    id: "output",
                    title: TokenMeteringL10n.text(.outputShare, language: language),
                    value: Self.formatPercentage(outputPercent),
                    detail: TokenMeteringL10n.tokenCountDetail(Self.formatTokens(outputTokens), language: language)
                ),
                TokenUsageDashboardKPI(
                    id: "latency",
                    title: TokenMeteringL10n.text(.avgLatency, language: language),
                    value: averageLatency.map { "\($0) ms" } ?? TokenMeteringL10n.text(.latencyUnavailable, language: language),
                    detail: averageLatency == nil
                        ? TokenMeteringL10n.text(.runtimeTimingUnavailable, language: language)
                        : TokenMeteringL10n.text(.perLocalSpan, language: language)
                )
            ]
        }

        toolRows = Self.rows(
            tokenValues: visibleCapturedToolTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let modelTokens = Dictionary(grouping: focusedEvents, by: { Self.modelKey($0.model) })
            .mapValues { $0.reduce(0) { $0 + $1.totalTokens } }
        modelRows = Self.rows(
            tokenValues: modelTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0 },
            label: { Self.modelLabel($0, language: language) }
        )

        let taskTokens = Dictionary(grouping: focusedEvents, by: \.taskType)
            .mapValues { $0.reduce(0) { $0 + $1.totalTokens } }
        taskRows = Self.rows(
            tokenValues: taskTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let stageTokens = Dictionary(grouping: focusedEvents, by: \.stage)
            .mapValues { $0.reduce(0) { $0 + $1.totalTokens } }
        stageRows = Self.rows(
            tokenValues: stageTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let sourceTokens = Self.sourceTotals(events: focusedEvents)
        sourceRows = Self.rows(
            tokenValues: sourceTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.label(language: language) }
        )

        sessions = sessionRows
        selectedSession = selectedSessionRow
        let calendarMonth = Self.normalizedCalendarMonthStart(
            events: dashboardEvents,
            now: now,
            proposedMonthStart: calendarMonthStart,
            calendar: calendar
        )
        let firstDataMonth = Self.firstDataMonthStart(
            events: dashboardEvents,
            now: now,
            calendar: calendar
        )
        let currentMonth = Self.monthStart(for: now, calendar: calendar)
        calendarMonthTitle = Self.formatCalendarMonth(calendarMonth, locale: locale, timeZone: timeZone)
        calendarWeekdayTitles = Self.weekdayTitles(locale: locale)
        canNavigatePreviousCalendarMonth = calendar.compare(calendarMonth, to: firstDataMonth, toGranularity: .month) == .orderedDescending
        canNavigateNextCalendarMonth = calendar.compare(calendarMonth, to: currentMonth, toGranularity: .month) == .orderedAscending
        calendarDays = Self.calendarDays(
            events: dashboardEvents,
            monthStart: calendarMonth,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        codexLastUpdatedString = codexLastUpdated.map {
            Self.formatLocalTimestamp($0, locale: locale, timeZone: timeZone)
        }
        claudeLastUpdatedString = claudeLastUpdated.map {
            Self.formatLocalTimestamp($0, locale: locale, timeZone: timeZone)
        }
        antigravityLastUpdatedString = antigravityLastUpdated.map {
            Self.formatLocalTimestamp($0, locale: locale, timeZone: timeZone)
        }
        overallLastUpdatedString = overallLastUpdated.map {
            Self.formatLocalTimestamp($0, locale: locale, timeZone: timeZone)
        }
    }

    private init(events: [TokenUsageEvent], selectedTool legacySelectedTool: TokenUsageAITool?) {
        self.init(events: events, selectedTool: legacySelectedTool, selectedPeriod: .all, selectedSessionID: nil, displayMode: .tokens)
    }

    static let empty = TokenUsageDashboardSnapshot(events: [])

    static func formatTokens(_ value: Int) -> String {
        let absoluteValue = Swift.abs(Double(value))
        let units: [(threshold: Double, divisor: Double, suffix: String)] = [
            (1_000_000_000_000, 1_000_000_000_000, "T"),
            (1_000_000_000, 1_000_000_000, "B"),
            (1_000_000, 1_000_000, "M"),
            (10_000, 1_000, "K")
        ]

        guard let unit = units.first(where: { absoluteValue >= $0.threshold }) else {
            return NumberFormatter.tokenUsageFull.string(from: NSNumber(value: value)) ?? "\(value)"
        }

        let scaledValue = Double(value) / unit.divisor
        let formattedValue = NumberFormatter.tokenUsageCompact.string(from: NSNumber(value: scaledValue))
            ?? String(format: "%.2f", scaledValue)
        return "\(formattedValue)\(unit.suffix)"
    }

    static func filterEvents(
        _ events: [TokenUsageEvent],
        selectedPeriod: TokenUsageDashboardPeriod,
        now: Date,
        calendar: Calendar
    ) -> [TokenUsageEvent] {
        guard let cutoff = cutoffDate(for: selectedPeriod, now: now, calendar: calendar) else {
            return events
        }

        return events.filter { event in
            guard let createdAt = ISO8601DateFormatter.parseTokenUsageDate(from: event.createdAt) else {
                return false
            }
            return createdAt >= cutoff && createdAt <= now
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
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .all:
            return nil
        }
    }

    static func visibleEvents(events: [TokenUsageEvent], selectedTool: TokenUsageAITool?) -> [TokenUsageEvent] {
        selectedTool.map { tool in
            events.filter { $0.aiTool == tool }
        } ?? events
    }

    static func formatPercentage(_ value: Double) -> String {
        if value > 0, value < 0.1 {
            return "<0.1%"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
        return "\(number)%"
    }

    private static func rows<Key: Hashable>(
        tokenValues: [Key: Int],
        totalTokens: Int,
        displayMode: TokenUsageDisplayMode,
        id: (Key) -> String,
        label: (Key) -> String
    ) -> [TokenUsageDashboardBarRow] {
        tokenValues.keys
            .compactMap { key -> TokenUsageDashboardBarRow? in
                let tokens = tokenValues[key, default: 0]

                guard tokens > 0 else { return nil }

                let valueStr: String
                let ratio: Double

                switch displayMode {
                case .tokens:
                    valueStr = Self.formatTokens(tokens)
                    ratio = totalTokens > 0 ? Double(tokens) / Double(totalTokens) : 0.0
                case .percentage:
                    let pct = totalTokens > 0 ? (Double(tokens) / Double(totalTokens)) * 100.0 : 0.0
                    valueStr = Self.formatPercentage(pct)
                    ratio = totalTokens > 0 ? Double(tokens) / Double(totalTokens) : 0.0
                }

                return TokenUsageDashboardBarRow(
                    id: id(key),
                    title: label(key),
                    value: valueStr,
                    ratio: ratio
                )
            }
            .sorted { (row1, row2) -> Bool in
                if row1.ratio == row2.ratio {
                    return row1.title < row2.title
                }
                return row1.ratio > row2.ratio
            }
    }

    private static func toolTotals(events: [TokenUsageEvent]) -> [TokenUsageAITool: Int] {
        Dictionary(grouping: events, by: \.aiTool)
            .mapValues { groupedEvents in
                groupedEvents.reduce(0) { $0 + $1.totalTokens }
            }
    }

    private static func toolFilters(
        selectedTool: TokenUsageAITool?,
        totals: [TokenUsageAITool: Int],
        totalEvents: Int,
        language: TokenMeteringLanguage
    ) -> [TokenUsageDashboardToolFilter] {
        let allTotal = totals.values.reduce(0, +)
        let allFilter = TokenUsageDashboardToolFilter(
            tool: nil,
            title: TokenMeteringL10n.text(.allTools, language: language),
            detail: TokenMeteringL10n.eventsTokensDetail(
                eventCount: totalEvents,
                tokens: formatTokens(allTotal),
                language: language
            ),
            isSelected: selectedTool == nil
        )
        let toolFilters = TokenUsageAITool.dashboardTools.map { tool in
            TokenUsageDashboardToolFilter(
                tool: tool,
                title: tool.dashboardLabel(language: language),
                detail: formatTokens(totals[tool, default: 0]),
                isSelected: selectedTool == tool
            )
        }

        return [allFilter] + toolFilters
    }

    private static func sourceTotals(events: [TokenUsageEvent]) -> [TokenUsageSource: Int] {
        var totals: [TokenUsageSource: Int] = [:]
        for event in events {
            totals[.system, default: 0] += event.tokenBreakdown.system
            totals[.user, default: 0] += event.tokenBreakdown.user
            totals[.history, default: 0] += event.tokenBreakdown.history
            totals[.repoContext, default: 0] += event.tokenBreakdown.repoContext
            totals[.toolOutput, default: 0] += event.tokenBreakdown.toolOutput
            totals[.generatedOutput, default: 0] += event.tokenBreakdown.generatedOutput
            totals[.unknown, default: 0] += event.tokenBreakdown.unknown
        }
        return totals
    }

    private static func sessionRows(
        events: [TokenUsageEvent],
        displayMode: TokenUsageDisplayMode,
        totalTokens: Int,
        language: TokenMeteringLanguage,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> [TokenUsageDashboardSessionRow] {
        Dictionary(grouping: events) { event in
            workItemKey(for: event, calendar: calendar)
        }
            .map { key, groupedEvents in
                let totalT = groupedEvents.reduce(0) { $0 + $1.totalTokens }
                let latency = groupedEvents.reduce(0) { $0 + $1.latencyMS }
                let latestDate = groupedEvents
                    .compactMap { ISO8601DateFormatter.parseTokenUsageDate(from: $0.createdAt) }
                    .max()
                let latestRaw = latestDate.map { ISO8601DateFormatter.tokenUsage.string(from: $0) }
                    ?? groupedEvents.map(\.createdAt).max()
                    ?? "unknown"
                let latestDisplay = latestDate.map {
                    Self.formatLocalTimestamp($0, locale: locale, timeZone: timeZone)
                } ?? latestRaw
                let runIDs = Set(groupedEvents.map(\.runID))

                let valueStr: String
                switch displayMode {
                case .tokens:
                    valueStr = Self.formatTokens(totalT)
                case .percentage:
                    let pct = totalTokens > 0 ? (Double(totalT) / Double(totalTokens)) * 100.0 : 0.0
                    valueStr = Self.formatPercentage(pct)
                }

                return (
                    row: TokenUsageDashboardSessionRow(
                        id: key.id,
                        runID: key.id,
                        title: Self.workItemTitle(key: key, language: language),
                        value: valueStr,
                        detail: TokenMeteringL10n.spansDetail(
                            spanCount: groupedEvents.count,
                            latencyMS: latency > 0 ? latency : nil,
                            latest: latestDisplay,
                            language: language
                        ),
                        eventCount: groupedEvents.count
                    ),
                    latest: latestRaw,
                    totalTokens: totalT,
                    spanCount: groupedEvents.count,
                    runCount: runIDs.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.latest != rhs.latest {
                    return lhs.latest > rhs.latest
                }
                if lhs.totalTokens != rhs.totalTokens {
                    return lhs.totalTokens > rhs.totalTokens
                }
                if lhs.spanCount != rhs.spanCount {
                    return lhs.spanCount > rhs.spanCount
                }
                if lhs.runCount != rhs.runCount {
                    return lhs.runCount > rhs.runCount
                }
                return lhs.row.title < rhs.row.title
            }
            .map(\.row)
    }

    private static func workItemKey(
        for event: TokenUsageEvent,
        calendar: Calendar
    ) -> TokenUsageDashboardWorkItemKey {
        TokenUsageDashboardWorkItemKey(
            taskType: event.taskType,
            stage: event.stage,
            dayBucket: localDayBucket(for: event.createdAt, calendar: calendar)
        )
    }

    static func workItemID(
        for event: TokenUsageEvent,
        calendar: Calendar
    ) -> String {
        workItemKey(for: event, calendar: calendar).id
    }

    private static func formatLocalTimestamp(
        _ date: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func localDayBucket(
        for createdAt: String,
        calendar: Calendar
    ) -> String {
        guard let date = ISO8601DateFormatter.parseTokenUsageDate(from: createdAt) else {
            return String(createdAt.prefix(10))
        }

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day
        else {
            return String(createdAt.prefix(10))
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func calendarDays(
        events: [TokenUsageEvent],
        monthStart: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> [TokenUsageDashboardCalendarDay] {
        guard let displayEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }

        let eventsByDay = Dictionary(grouping: events) { event in
            localDayBucket(for: event.createdAt, calendar: calendar)
        }
        let maxTokens = max(1, eventsByDay.values.map { groupedEvents in
            groupedEvents.reduce(0) { $0 + $1.totalTokens }
        }.max() ?? 0)

        let dayFormatter = DateFormatter()
        dayFormatter.locale = locale
        dayFormatter.timeZone = timeZone
        dayFormatter.dateFormat = "d"

        var days: [TokenUsageDashboardCalendarDay] = []
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingPlaceholderCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        for index in 0..<leadingPlaceholderCount {
            days.append(TokenUsageDashboardCalendarDay(
                id: "placeholder-leading-\(localDayBucket(for: ISO8601DateFormatter.tokenUsage.string(from: monthStart), calendar: calendar))-\(index)",
                day: 0,
                title: "",
                detail: "",
                ratio: 0.0,
                isCurrentMonth: false,
                hasEvents: false,
                isPlaceholder: true
            ))
        }

        var cursor = calendar.startOfDay(for: monthStart)
        while cursor < displayEnd {
            let dayBucket = localDayBucket(
                for: ISO8601DateFormatter.tokenUsage.string(from: cursor),
                calendar: calendar
            )
            let groupedEvents = eventsByDay[dayBucket, default: []]
            let tokens = groupedEvents.reduce(0) { $0 + $1.totalTokens }
            let day = calendar.component(.day, from: cursor)
            days.append(TokenUsageDashboardCalendarDay(
                id: dayBucket,
                day: day,
                title: dayFormatter.string(from: cursor),
                detail: formatTokens(tokens),
                ratio: tokens > 0 ? Double(tokens) / Double(maxTokens) : 0.0,
                isCurrentMonth: true,
                hasEvents: !groupedEvents.isEmpty,
                isPlaceholder: false
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        let trailingPlaceholderCount = (7 - (days.count % 7)) % 7
        for index in 0..<trailingPlaceholderCount {
            days.append(TokenUsageDashboardCalendarDay(
                id: "placeholder-trailing-\(localDayBucket(for: ISO8601DateFormatter.tokenUsage.string(from: monthStart), calendar: calendar))-\(index)",
                day: 0,
                title: "",
                detail: "",
                ratio: 0.0,
                isCurrentMonth: false,
                hasEvents: false,
                isPlaceholder: true
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

    static func monthStart(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
    }

    private static func firstDataMonthStart(
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

    private static func formatCalendarMonth(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    private static func weekdayTitles(locale: Locale) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter.veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
    }

    private static func workItemTitle(
        key: TokenUsageDashboardWorkItemKey,
        language: TokenMeteringLanguage
    ) -> String {
        [
            key.taskType.dashboardLabel(language: language),
            key.stage.dashboardLabel(language: language)
        ].joined(separator: " - ")
    }

    private static func modelKey(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        if trimmed.isEmpty || lowered == "unknown" || lowered == "unknown_model" || lowered == "model_unknown" || lowered == "unavailable" {
            return "model_unavailable"
        }
        return trimmed
    }

    private static func modelLabel(_ key: String, language: TokenMeteringLanguage) -> String {
        key == "model_unavailable"
            ? TokenMeteringL10n.text(.modelUnavailable, language: language)
            : key
    }

    private static func percentageDetail(value: Int, total: Int, language: TokenMeteringLanguage) -> String {
        let percent = total > 0 ? (Double(value) / Double(total) * 100.0) : 0.0
        return TokenMeteringL10n.percentStringOfTotal(Self.formatPercentage(percent), language: language)
    }
}

private struct TokenUsageDashboardWorkItemKey: Hashable {
    let taskType: TokenUsageTaskType
    let stage: TokenUsageStage
    let dayBucket: String

    var id: String {
        [
            "work",
            taskType.rawValue,
            stage.rawValue,
            dayBucket
        ]
            .map(Self.safeIDPart)
            .joined(separator: "_")
    }

    private static func safeIDPart(_ value: String) -> String {
        let scalars = value.lowercased().unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "_"
        }
        return scalars.joined()
            .split(separator: "_")
            .joined(separator: "_")
    }
}

enum TokenMeteringPreferencesModel {
    static var modes: [TokenMeteringModeStatus] {
        [
            TokenMeteringModeStatus(
                id: "local_only",
                title: TokenMeteringL10n.text(.modeLocalOnlyTitle),
                state: TokenMeteringL10n.text(.modeLocalOnlyState),
                detail: TokenMeteringL10n.text(.modeLocalOnlyDetail),
                isActive: true
            ),
            TokenMeteringModeStatus(
                id: "cloud_aggregate",
                title: TokenMeteringL10n.text(.modeCloudAggregateTitle),
                state: TokenMeteringL10n.text(.modeCloudAggregateState),
                detail: TokenMeteringL10n.text(.modeCloudAggregateDetail),
                isActive: false
            ),
            TokenMeteringModeStatus(
                id: "cloud_detailed",
                title: TokenMeteringL10n.text(.modeCloudDetailedTitle),
                state: TokenMeteringL10n.text(.modeCloudDetailedState),
                detail: TokenMeteringL10n.text(.modeCloudDetailedDetail),
                isActive: false
            )
        ]
    }

    static var forbiddenContentLabels: [String] {
        TokenMeteringL10n.forbiddenContentLabels()
    }
}

private enum TokenUsageSource: Hashable {
    case system
    case user
    case history
    case repoContext
    case toolOutput
    case generatedOutput
    case unknown

    func label(language: TokenMeteringLanguage) -> String {
        switch self {
        case .system:
            return TokenMeteringL10n.text(.sourceSystem, language: language)
        case .user:
            return TokenMeteringL10n.text(.sourceUser, language: language)
        case .history:
            return TokenMeteringL10n.text(.sourceHistory, language: language)
        case .repoContext:
            return TokenMeteringL10n.text(.sourceRepoContext, language: language)
        case .toolOutput:
            return TokenMeteringL10n.text(.sourceToolOutput, language: language)
        case .generatedOutput:
            return TokenMeteringL10n.text(.sourceGeneratedOutput, language: language)
        case .unknown:
            return TokenMeteringL10n.text(.sourceUnavailable, language: language)
        }
    }
}

extension TokenUsageSource {
    var rawValue: String {
        switch self {
        case .system:
            return "system"
        case .user:
            return "user"
        case .history:
            return "history"
        case .repoContext:
            return "repo_context"
        case .toolOutput:
            return "tool_output"
        case .generatedOutput:
            return "generated_output"
        case .unknown:
            return "unknown"
        }
    }
}

extension TokenUsageAITool {
    var dashboardLabel: String {
        dashboardLabel(language: .current())
    }

    func dashboardLabel(language: TokenMeteringLanguage) -> String {
        switch self {
        case .unknown:
            return TokenMeteringL10n.text(.unknownAITool, language: language)
        case .codex:
            return "Codex"
        case .claude:
            return "Claude"
        case .antigravity:
            return "Antigravity (agy)"
        case .openAI:
            return "OpenAI"
        }
    }
}

private extension TokenUsageTaskType {
    func dashboardLabel(language: TokenMeteringLanguage) -> String {
        TokenMeteringL10n.taskLabel(rawValue, language: language)
    }
}

private extension TokenUsageStage {
    func dashboardLabel(language: TokenMeteringLanguage) -> String {
        TokenMeteringL10n.stageLabel(rawValue, language: language)
    }
}

private extension NumberFormatter {
    static let tokenUsageFull: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let tokenUsageCompact: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
