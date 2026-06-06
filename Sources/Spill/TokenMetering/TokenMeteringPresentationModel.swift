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

struct TokenUsagePanelSummarySnapshot: Equatable {
    let eventCount: Int
    let totalTokens: Int
    let displayMode: TokenUsageDisplayMode
    let toolRows: [TokenUsageDashboardBarRow]
    let taskRows: [TokenUsageDashboardBarRow]
    let sourceRows: [TokenUsageDashboardBarRow]

    init(
        summary: TokenUsageDashboardSummary,
        displayMode: TokenUsageDisplayMode = .tokens,
        language: TokenMeteringLanguage = .current()
    ) {
        eventCount = summary.eventCount
        totalTokens = summary.totalTokens
        self.displayMode = displayMode

        let toolTotals = summary.toolTotals.reduce(into: [TokenUsageAITool: Int]()) { totals, element in
            guard let tool = TokenUsageAITool(rawValue: element.key) else {
                return
            }
            totals[tool] = element.value
        }
        toolRows = Self.rows(
            tokenValues: toolTotals,
            totalTokens: summary.totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let taskTotals = summary.taskTotals.reduce(into: [TokenUsageTaskType: Int]()) { totals, element in
            guard let taskType = TokenUsageTaskType(rawValue: element.key) else {
                return
            }
            totals[taskType] = element.value
        }
        taskRows = Self.rows(
            tokenValues: taskTotals,
            totalTokens: summary.totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let sourceTotals = summary.sourceTotals.reduce(into: [TokenUsageSource: Int]()) { totals, element in
            guard let source = TokenUsageSource(rawValue: element.key) else {
                return
            }
            totals[source] = element.value
        }
        sourceRows = Self.rows(
            tokenValues: sourceTotals,
            totalTokens: summary.totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.label(language: language) }
        )
    }

    init(snapshot: TokenUsageDashboardSnapshot) {
        eventCount = snapshot.eventCount
        totalTokens = snapshot.totalTokens
        displayMode = snapshot.displayMode
        toolRows = snapshot.toolRows
        taskRows = snapshot.taskRows
        sourceRows = snapshot.sourceRows
    }

    static let empty = TokenUsagePanelSummarySnapshot(summary: .empty)

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
                guard tokens > 0 else {
                    return nil
                }

                let value: String
                let ratio = totalTokens > 0 ? Double(tokens) / Double(totalTokens) : 0.0
                switch displayMode {
                case .tokens:
                    value = TokenUsageDashboardSnapshot.formatTokens(tokens)
                case .percentage:
                    value = TokenUsageDashboardSnapshot.formatPercentage(ratio * 100.0)
                }

                return TokenUsageDashboardBarRow(
                    id: id(key),
                    title: label(key),
                    value: value,
                    ratio: ratio
                )
            }
            .sorted { lhs, rhs in
                if lhs.ratio == rhs.ratio {
                    return lhs.title < rhs.title
                }
                return lhs.ratio > rhs.ratio
            }
    }
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
    let isToday: Bool
    let isSelected: Bool
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
    let selectedCalendarDayID: String?
    let selectedCalendarDayTitle: String?
    let todayCalendarDayID: String
    let todayCalendarDayTitle: String
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
    let comparisonTotalTokens: Int?

    static func buildPair(
        events: [TokenUsageEvent],
        selectedTool: TokenUsageAITool?,
        selectedPeriod: TokenUsageDashboardPeriod,
        selectedCalendarDayID: String?,
        selectedSessionID: String?,
        displayMode: TokenUsageDisplayMode,
        language: TokenMeteringLanguage,
        localAliases: [String: String],
        showAdvancedTools: Bool,
        now: Date,
        proposedCalendarMonthStart: Date?,
        calendar: Calendar,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> TokenUsageDashboardSnapshotPair {
        let context = TokenUsageDashboardSnapshotBuildContext(
            events: events,
            showAdvancedTools: showAdvancedTools,
            calendar: calendar
        )
        let selectedDayMonth = selectedCalendarDayID
            .flatMap { date(forDayID: $0, calendar: calendar) }
            .map { monthStart(for: $0, calendar: calendar) }
        let displayCalendarMonth = normalizedCalendarMonthStart(
            events: context.dashboardEvents,
            now: now,
            proposedMonthStart: proposedCalendarMonthStart ?? selectedDayMonth,
            calendar: calendar
        )
        let filtered = TokenUsageDashboardSnapshot(
            context: context,
            selectedTool: selectedTool,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID,
            selectedSessionID: selectedSessionID,
            displayMode: displayMode,
            language: language,
            localAliases: localAliases,
            showAdvancedTools: showAdvancedTools,
            now: now,
            calendarMonthStart: displayCalendarMonth,
            resolvedCalendarMonthStart: displayCalendarMonth,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )
        let unfiltered = selectedTool == nil
            ? filtered
            : TokenUsageDashboardSnapshot(
                context: context,
                selectedTool: nil,
                selectedPeriod: selectedPeriod,
                selectedCalendarDayID: selectedCalendarDayID,
                selectedSessionID: nil,
                displayMode: displayMode,
                language: language,
                localAliases: localAliases,
                showAdvancedTools: showAdvancedTools,
                now: now,
                calendarMonthStart: displayCalendarMonth,
                resolvedCalendarMonthStart: displayCalendarMonth,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            )

        return TokenUsageDashboardSnapshotPair(
            filtered: filtered,
            unfiltered: unfiltered,
            calendarMonthStart: displayCalendarMonth
        )
    }

    init(
        events: [TokenUsageEvent],
        selectedTool: TokenUsageAITool? = nil,
        selectedPeriod: TokenUsageDashboardPeriod = .all,
        selectedCalendarDayID: String? = nil,
        selectedSessionID: String? = nil,
        displayMode: TokenUsageDisplayMode = .tokens,
        language: TokenMeteringLanguage = .current(),
        localAliases: [String: String] = [:],
        showAdvancedTools: Bool = false,
        now: Date = Date(),
        calendarMonthStart: Date? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.init(
            context: TokenUsageDashboardSnapshotBuildContext(
                events: events,
                showAdvancedTools: showAdvancedTools,
                calendar: calendar
            ),
            selectedTool: selectedTool,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID,
            selectedSessionID: selectedSessionID,
            displayMode: displayMode,
            language: language,
            localAliases: localAliases,
            showAdvancedTools: showAdvancedTools,
            now: now,
            calendarMonthStart: calendarMonthStart,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )
    }

    private init(
        context: TokenUsageDashboardSnapshotBuildContext,
        selectedTool: TokenUsageAITool? = nil,
        selectedPeriod: TokenUsageDashboardPeriod = .all,
        selectedCalendarDayID: String? = nil,
        selectedSessionID: String? = nil,
        displayMode: TokenUsageDisplayMode = .tokens,
        language: TokenMeteringLanguage = .current(),
        localAliases: [String: String] = [:],
        showAdvancedTools: Bool = false,
        now: Date = Date(),
        calendarMonthStart: Date? = nil,
        resolvedCalendarMonthStart: Date? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.displayMode = displayMode
        let dashboardEvents = context.dashboardEvents
        let selectedDayID = selectedCalendarDayID.flatMap { Self.date(forDayID: $0, calendar: calendar) == nil ? nil : $0 }
        self.selectedCalendarDayID = selectedDayID
        selectedCalendarDayTitle = selectedDayID.flatMap {
            Self.formatCalendarDayID($0, calendar: calendar, locale: locale, timeZone: timeZone)
        }
        todayCalendarDayID = Self.dayID(for: now, calendar: calendar)
        todayCalendarDayTitle = Self.formatCalendarDayTitle(now, locale: locale, timeZone: timeZone)

        codexLastUpdated = dashboardEvents
            .filter { $0.event.aiTool == .codex }
            .compactMap(\.createdAt)
            .max()
        claudeLastUpdated = dashboardEvents
            .filter { $0.event.aiTool == .claude }
            .compactMap(\.createdAt)
            .max()
        antigravityLastUpdated = dashboardEvents
            .filter { $0.event.aiTool == .antigravity }
            .compactMap(\.createdAt)
            .max()
        overallLastUpdated = dashboardEvents
            .compactMap(\.createdAt)
            .max()

        let selectedDashboardTool = selectedTool.flatMap { tool in
            tool.isDashboardTool ? tool : nil
        }
        let periodEvents = Self.filteredParsedEvents(
            dashboardEvents,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedDayID,
            now: now,
            calendar: calendar
        )
        let visibleEvents = selectedDashboardTool.map { tool in
            periodEvents.filter { $0.event.aiTool == tool }
        } ?? periodEvents
        let sessionRows = Self.sessionRows(
            events: visibleEvents,
            displayMode: displayMode,
            totalTokens: visibleEvents.reduce(0) { $0 + $1.event.totalTokens },
            language: language,
            localAliases: localAliases,
            calendar: calendar,
            now: now,
            locale: locale,
            timeZone: timeZone
        )
        let selectedSessionRow = selectedSessionID.flatMap { id in
            sessionRows.first { $0.id == id }
        }
        let focusedEvents = selectedSessionRow.map { session in
            visibleEvents.filter {
                Self.workItemID(for: $0) == session.id
            }
        } ?? visibleEvents

        eventCount = focusedEvents.count
        let capturedTotalTokens = focusedEvents.reduce(0) { $0 + $1.event.totalTokens }
        totalTokens = capturedTotalTokens
        let visibleCapturedToolTokens = Self.toolTotals(events: focusedEvents)

        periodFilters = TokenUsageDashboardPeriod.allCases.map { period in
            let periodCapturedEvents = Self.filteredParsedEvents(
                dashboardEvents,
                selectedPeriod: period,
                now: now,
                calendar: calendar
            )
            let capturedPeriodTotal = periodCapturedEvents.reduce(0) { $0 + $1.event.totalTokens }
            return TokenUsageDashboardPeriodFilter(
                period: period,
                title: period.title(language: language),
                detail: Self.formatTokens(capturedPeriodTotal),
                isSelected: selectedDayID == nil && selectedPeriod == period
            )
        }

        let allToolTotals = Self.toolTotals(events: periodEvents)
        toolFilters = Self.toolFilters(
            selectedTool: selectedDashboardTool,
            totals: allToolTotals,
            totalEvents: periodEvents.count,
            showAdvancedTools: showAdvancedTools,
            language: language
        )

        let inputTokens = focusedEvents.reduce(0) { $0 + $1.event.inputTokens }
        let outputTokens = focusedEvents.reduce(0) { $0 + $1.event.outputTokens }

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

        let modelTokens = Self.tokenTotals(events: focusedEvents) { Self.modelKey($0.event.model) }
        modelRows = Self.rows(
            tokenValues: modelTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0 },
            label: { Self.modelLabel($0, language: language) }
        )

        let taskTokens = Self.tokenTotals(events: focusedEvents) { $0.event.taskType }
        taskRows = Self.rows(
            tokenValues: taskTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let stageTokens = Self.tokenTotals(events: focusedEvents) { $0.event.stage }
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

        // Comparison period tokens (nil when a work item is selected or period is .all)
        if selectedSessionRow != nil || selectedDayID != nil {
            comparisonTotalTokens = nil
        } else {
            let toolFilteredEvents = selectedDashboardTool
                .map { tool in dashboardEvents.filter { $0.event.aiTool == tool } } ?? dashboardEvents
            switch selectedPeriod {
            case .today:
                let todayStart = calendar.startOfDay(for: now)
                let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
                let compEvents = toolFilteredEvents.filter { event in
                    guard let date = event.createdAt else { return false }
                    return date >= yesterdayStart && date < todayStart
                }
                comparisonTotalTokens = compEvents.isEmpty ? nil : compEvents.reduce(0) { $0 + $1.event.totalTokens }
            case .sevenDays:
                let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
                let fourteenDaysAgo = calendar.date(byAdding: .day, value: -7, to: sevenDaysAgo) ?? now
                let compEvents = toolFilteredEvents.filter { event in
                    guard let date = event.createdAt else { return false }
                    return date >= fourteenDaysAgo && date < sevenDaysAgo
                }
                comparisonTotalTokens = compEvents.isEmpty ? nil : compEvents.reduce(0) { $0 + $1.event.totalTokens }
            case .thirtyDays:
                let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
                let sixtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: thirtyDaysAgo) ?? now
                let compEvents = toolFilteredEvents.filter { event in
                    guard let date = event.createdAt else { return false }
                    return date >= sixtyDaysAgo && date < thirtyDaysAgo
                }
                comparisonTotalTokens = compEvents.isEmpty ? nil : compEvents.reduce(0) { $0 + $1.event.totalTokens }
            case .all:
                comparisonTotalTokens = nil
            }
        }

        let selectedDayMonth = selectedDayID
            .flatMap { Self.date(forDayID: $0, calendar: calendar) }
            .map { Self.monthStart(for: $0, calendar: calendar) }
        let calendarMonth = resolvedCalendarMonthStart ?? Self.normalizedCalendarMonthStart(
            events: dashboardEvents,
            now: now,
            proposedMonthStart: calendarMonthStart ?? selectedDayMonth,
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
            selectedCalendarDayID: selectedDayID,
            todayCalendarDayID: todayCalendarDayID,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        codexLastUpdatedString = codexLastUpdated.map {
            Self.formatLocalTimestamp($0, now: now, calendar: calendar, locale: locale, timeZone: timeZone)
        }
        claudeLastUpdatedString = claudeLastUpdated.map {
            Self.formatLocalTimestamp($0, now: now, calendar: calendar, locale: locale, timeZone: timeZone)
        }
        antigravityLastUpdatedString = antigravityLastUpdated.map {
            Self.formatLocalTimestamp($0, now: now, calendar: calendar, locale: locale, timeZone: timeZone)
        }
        overallLastUpdatedString = overallLastUpdated.map {
            Self.formatLocalTimestamp($0, now: now, calendar: calendar, locale: locale, timeZone: timeZone)
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
        selectedCalendarDayID: String? = nil,
        now: Date,
        calendar: Calendar
    ) -> [TokenUsageEvent] {
        if let selectedCalendarDayID {
            return events.filter { event in
                localDayBucket(for: event.createdAt, calendar: calendar) == selectedCalendarDayID
            }
        }

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

    private static func filteredParsedEvents(
        _ events: [TokenUsageDashboardParsedEvent],
        selectedPeriod: TokenUsageDashboardPeriod,
        selectedCalendarDayID: String? = nil,
        now: Date,
        calendar: Calendar
    ) -> [TokenUsageDashboardParsedEvent] {
        if let selectedCalendarDayID {
            return events.filter { $0.dayBucket == selectedCalendarDayID }
        }

        guard let cutoff = cutoffDate(for: selectedPeriod, now: now, calendar: calendar) else {
            return events
        }

        return events.filter { event in
            guard let createdAt = event.createdAt else {
                return false
            }
            return createdAt >= cutoff && createdAt <= now
        }
    }

    static func formatPercentage(_ value: Double) -> String {
        if value > 0, value < 0.1 {
            return "<0.1%"
        }

        let number = NumberFormatter.tokenUsagePercentage.string(from: NSNumber(value: value))
            ?? String(format: "%.1f", value)
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

    private static func tokenTotals<Key: Hashable>(
        events: [TokenUsageDashboardParsedEvent],
        by key: (TokenUsageDashboardParsedEvent) -> Key
    ) -> [Key: Int] {
        var totals: [Key: Int] = [:]
        for event in events {
            totals[key(event), default: 0] += event.event.totalTokens
        }
        return totals
    }

    private static func toolTotals(events: [TokenUsageDashboardParsedEvent]) -> [TokenUsageAITool: Int] {
        tokenTotals(events: events) { $0.event.aiTool }
    }

    private static func toolFilters(
        selectedTool: TokenUsageAITool?,
        totals: [TokenUsageAITool: Int],
        totalEvents: Int,
        showAdvancedTools: Bool,
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
        let toolsToShow: [TokenUsageAITool] = showAdvancedTools
            ? TokenUsageAITool.allCases
            : TokenUsageAITool.dashboardTools
        let toolFilters = toolsToShow.map { tool in
            TokenUsageDashboardToolFilter(
                tool: tool,
                title: tool.dashboardLabel(language: language),
                detail: formatTokens(totals[tool, default: 0]),
                isSelected: selectedTool == tool
            )
        }

        return [allFilter] + toolFilters
    }

    private static func sourceTotals(events: [TokenUsageDashboardParsedEvent]) -> [TokenUsageSource: Int] {
        var totals: [TokenUsageSource: Int] = [:]
        for parsedEvent in events {
            let event = parsedEvent.event
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
        events: [TokenUsageDashboardParsedEvent],
        displayMode: TokenUsageDisplayMode,
        totalTokens: Int,
        language: TokenMeteringLanguage,
        localAliases: [String: String],
        calendar: Calendar,
        now: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> [TokenUsageDashboardSessionRow] {
        Dictionary(grouping: events) { event in
            workItemKey(for: event)
        }
            .map { key, groupedEvents in
                let totalT = groupedEvents.reduce(0) { $0 + $1.event.totalTokens }
                let latency = groupedEvents.reduce(0) { $0 + $1.event.latencyMS }
                let latestDate = groupedEvents
                    .compactMap(\.createdAt)
                    .max()
                let latestRaw = latestDate.map { ISO8601DateFormatter.tokenUsage.string(from: $0) }
                    ?? groupedEvents.map(\.event.createdAt).max()
                    ?? "unknown"
                let latestDisplay = latestDate.map {
                    Self.formatLocalTimestamp($0, now: now, calendar: calendar, locale: locale, timeZone: timeZone)
                } ?? latestRaw
                let runIDs = Set(groupedEvents.map(\.event.runID))

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
                        title: localAliases[key.id] ?? Self.workItemTitle(key: key, language: language),
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

    private static func workItemKey(
        for event: TokenUsageDashboardParsedEvent
    ) -> TokenUsageDashboardWorkItemKey {
        TokenUsageDashboardWorkItemKey(
            taskType: event.event.taskType,
            stage: event.event.stage,
            dayBucket: event.dayBucket
        )
    }

    private static func workItemID(
        for event: TokenUsageDashboardParsedEvent
    ) -> String {
        workItemKey(for: event).id
    }

    private static func formatLocalTimestamp(
        _ date: Date,
        now: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        var calendar = calendar
        calendar.timeZone = timeZone

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone

        if calendar.isDate(date, inSameDayAs: now) {
            formatter.setLocalizedDateFormatFromTemplate("jm")
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            formatter.setLocalizedDateFormatFromTemplate("MMM d jm")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("y MMM d jm")
        }

        return formatter.string(from: date)
    }

    private static func localDayBucket(
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

    private static func formatCalendarDayID(
        _ dayID: String,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> String? {
        date(forDayID: dayID, calendar: calendar).map {
            formatCalendarDayTitle($0, locale: locale, timeZone: timeZone)
        }
    }

    private static func formatCalendarDayTitle(
        _ date: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    private static func calendarDays(
        events: [TokenUsageDashboardParsedEvent],
        monthStart: Date,
        selectedCalendarDayID: String?,
        todayCalendarDayID: String,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> [TokenUsageDashboardCalendarDay] {
        guard let displayEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }

        let eventsByDay = Dictionary(grouping: events) { event in
            event.dayBucket
        }
        let maxTokens = max(1, eventsByDay.values.map { groupedEvents in
            groupedEvents.reduce(0) { $0 + $1.event.totalTokens }
        }.max() ?? 0)

        let dayFormatter = DateFormatter()
        dayFormatter.locale = locale
        dayFormatter.timeZone = timeZone
        dayFormatter.dateFormat = "d"
        let calendarDayTitleFormatter = DateFormatter()
        calendarDayTitleFormatter.locale = locale
        calendarDayTitleFormatter.timeZone = timeZone
        calendarDayTitleFormatter.setLocalizedDateFormatFromTemplate("MMM d")

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
            let groupedEvents = eventsByDay[dayBucket, default: []]
            let tokens = groupedEvents.reduce(0) { $0 + $1.event.totalTokens }
            let day = calendar.component(.day, from: cursor)
            let calendarDayTitle = calendarDayTitleFormatter.string(from: cursor)
            days.append(TokenUsageDashboardCalendarDay(
                id: dayBucket,
                day: day,
                title: dayFormatter.string(from: cursor),
                detail: "\(calendarDayTitle) · \(formatTokens(tokens))",
                ratio: tokens > 0 ? Double(tokens) / Double(maxTokens) : 0.0,
                isCurrentMonth: true,
                hasEvents: !groupedEvents.isEmpty,
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

    private static func normalizedCalendarMonthStart(
        events: [TokenUsageDashboardParsedEvent],
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

    private static func firstDataMonthStart(
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

private struct TokenUsageDashboardParsedEvent {
    let event: TokenUsageEvent
    let createdAt: Date?
    let dayBucket: String

    init(event: TokenUsageEvent, calendar: Calendar) {
        self.event = event
        let parsedDate = ISO8601DateFormatter.parseTokenUsageDate(from: event.createdAt)
        self.createdAt = parsedDate
        self.dayBucket = parsedDate.map {
            TokenUsageDashboardSnapshot.dayID(for: $0, calendar: calendar)
        } ?? String(event.createdAt.prefix(10))
    }
}

struct TokenUsageDashboardSnapshotPair {
    let filtered: TokenUsageDashboardSnapshot
    let unfiltered: TokenUsageDashboardSnapshot
    let calendarMonthStart: Date
}

private struct TokenUsageDashboardSnapshotBuildContext {
    let dashboardEvents: [TokenUsageDashboardParsedEvent]

    init(
        events: [TokenUsageEvent],
        showAdvancedTools: Bool,
        calendar: Calendar
    ) {
        dashboardEvents = events.compactMap { event -> TokenUsageDashboardParsedEvent? in
            if showAdvancedTools {
                return TokenUsageDashboardParsedEvent(event: event, calendar: calendar)
            }

            return event.aiTool.isDashboardTool
                ? TokenUsageDashboardParsedEvent(event: event, calendar: calendar)
                : nil
        }
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

private enum TokenUsageSource: String, Hashable {
    case system
    case user
    case history
    case repoContext = "repo_context"
    case toolOutput = "tool_output"
    case generatedOutput = "generated_output"
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

    static let tokenUsagePercentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}
