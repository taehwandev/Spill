import Foundation

struct TokenUsageDashboardSnapshot: Equatable {
    let eventCount: Int
    let totalTokens: Int
    let displayMode: TokenUsageDisplayMode
    let kpis: [TokenUsageDashboardKPI]
    let periodFilters: [TokenUsageDashboardPeriodFilter]
    let toolFilters: [TokenUsageDashboardToolFilter]
    let projectFilters: [TokenUsageDashboardProjectFilter]
    let selectedProjectID: String?
    let toolRows: [TokenUsageDashboardBarRow]
    let modelRows: [TokenUsageDashboardBarRow]
    let workflowUsage: TokenUsageDashboardWorkflowUsage
    let taskRows: [TokenUsageDashboardBarRow]
    let stageRows: [TokenUsageDashboardBarRow]
    let sourceRows: [TokenUsageDashboardBarRow]
    let sessions: [TokenUsageDashboardSessionRow]
    let selectedSession: TokenUsageDashboardSessionRow?
    let trendBuckets: [TokenUsageDashboardTrendBucket]
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
    let canNavigatePreviousPeriod: Bool
    let canNavigateNextPeriod: Bool

    static func buildPair(
        events: [TokenUsageEvent],
        selectedTool: TokenUsageAITool?,
        selectedPeriod: TokenUsageDashboardPeriod,
        selectedCalendarDayID: String?,
        selectedProjectID: String?,
        selectedSessionID: String?,
        displayMode: TokenUsageDisplayMode,
        language: TokenMeteringLanguage,
        localAliases: [String: String],
        showAdvancedTools: Bool,
        now: Date,
        proposedCalendarMonthStart: Date?,
        calendar: Calendar,
        periodFilterTotals: [TokenUsageDashboardPeriod: Int]? = nil,
        availableDateBounds: TokenUsageDashboardDateBounds? = nil,
        periodOffset: Int = 0,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> TokenUsageDashboardSnapshotPair {
        let context = TokenUsageDashboardSnapshotBuildContext(
            events: events,
            showAdvancedTools: showAdvancedTools,
            calendar: calendar
        )
        return buildPair(
            context: context,
            selectedTool: selectedTool,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID,
            selectedProjectID: selectedProjectID,
            selectedSessionID: selectedSessionID,
            displayMode: displayMode,
            language: language,
            localAliases: localAliases,
            showAdvancedTools: showAdvancedTools,
            now: now,
            proposedCalendarMonthStart: proposedCalendarMonthStart,
            calendar: calendar,
            periodFilterTotals: periodFilterTotals,
            availableDateBounds: availableDateBounds,
            periodOffset: periodOffset,
            locale: locale,
            timeZone: timeZone
        )
    }

    static func buildPair(
        context: TokenUsageDashboardSnapshotBuildContext,
        selectedTool: TokenUsageAITool?,
        selectedPeriod: TokenUsageDashboardPeriod,
        selectedCalendarDayID: String?,
        selectedProjectID: String?,
        selectedSessionID: String?,
        displayMode: TokenUsageDisplayMode,
        language: TokenMeteringLanguage,
        localAliases: [String: String],
        showAdvancedTools: Bool,
        now: Date,
        proposedCalendarMonthStart: Date?,
        calendar: Calendar,
        periodFilterTotals: [TokenUsageDashboardPeriod: Int]? = nil,
        availableDateBounds: TokenUsageDashboardDateBounds? = nil,
        periodOffset: Int = 0,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> TokenUsageDashboardSnapshotPair {
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
            selectedProjectID: selectedProjectID,
            selectedSessionID: selectedSessionID,
            displayMode: displayMode,
            language: language,
            localAliases: localAliases,
            showAdvancedTools: showAdvancedTools,
            now: now,
            calendarMonthStart: displayCalendarMonth,
            resolvedCalendarMonthStart: displayCalendarMonth,
            periodFilterTotals: periodFilterTotals,
            availableDateBounds: availableDateBounds,
            periodOffset: periodOffset,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )
        let unfiltered = selectedTool == nil && selectedProjectID == nil
            ? filtered
            : TokenUsageDashboardSnapshot(
                context: context,
                selectedTool: nil,
                selectedPeriod: selectedPeriod,
                selectedCalendarDayID: selectedCalendarDayID,
                selectedProjectID: nil,
                selectedSessionID: nil,
                displayMode: displayMode,
                language: language,
                localAliases: localAliases,
                showAdvancedTools: showAdvancedTools,
                now: now,
                calendarMonthStart: displayCalendarMonth,
                resolvedCalendarMonthStart: displayCalendarMonth,
                periodFilterTotals: periodFilterTotals,
                availableDateBounds: availableDateBounds,
                periodOffset: periodOffset,
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
        selectedProjectID: String? = nil,
        selectedSessionID: String? = nil,
        displayMode: TokenUsageDisplayMode = .tokens,
        language: TokenMeteringLanguage = .current(),
        localAliases: [String: String] = [:],
        showAdvancedTools: Bool = false,
        now: Date = Date(),
        calendarMonthStart: Date? = nil,
        periodFilterTotals: [TokenUsageDashboardPeriod: Int]? = nil,
        availableDateBounds: TokenUsageDashboardDateBounds? = nil,
        periodOffset: Int = 0,
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
            selectedProjectID: selectedProjectID,
            selectedSessionID: selectedSessionID,
            displayMode: displayMode,
            language: language,
            localAliases: localAliases,
            showAdvancedTools: showAdvancedTools,
            now: now,
            calendarMonthStart: calendarMonthStart,
            resolvedCalendarMonthStart: nil,
            periodFilterTotals: periodFilterTotals,
            availableDateBounds: availableDateBounds,
            periodOffset: periodOffset,
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
        selectedProjectID: String? = nil,
        selectedSessionID: String? = nil,
        displayMode: TokenUsageDisplayMode = .tokens,
        language: TokenMeteringLanguage = .current(),
        localAliases: [String: String] = [:],
        showAdvancedTools: Bool = false,
        now: Date = Date(),
        calendarMonthStart: Date? = nil,
        resolvedCalendarMonthStart: Date? = nil,
        periodFilterTotals: [TokenUsageDashboardPeriod: Int]? = nil,
        availableDateBounds: TokenUsageDashboardDateBounds? = nil,
        periodOffset: Int = 0,
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

        let lastUpdatedDates = Self.lastUpdatedDates(in: dashboardEvents)
        codexLastUpdated = lastUpdatedDates.codex
        claudeLastUpdated = lastUpdatedDates.claude
        antigravityLastUpdated = lastUpdatedDates.antigravity
        overallLastUpdated = lastUpdatedDates.overall

        let selectedDashboardTool = selectedTool.flatMap { tool in
            tool.isDashboardTool ? tool : nil
        }
        let periodEvents = Self.filteredParsedEvents(
            dashboardEvents,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedDayID,
            now: now,
            calendar: calendar,
            periodOffset: periodOffset
        )
        let toolVisibleEvents = selectedDashboardTool.map { tool in
            periodEvents.filter { $0.event.aiTool == tool }
        } ?? periodEvents
        let validSelectedProjectID = selectedProjectID.flatMap { projectID in
            toolVisibleEvents.contains { $0.event.projectID == projectID } ? projectID : nil
        }
        self.selectedProjectID = validSelectedProjectID
        projectFilters = Self.projectFilters(
            events: toolVisibleEvents,
            selectedProjectID: validSelectedProjectID,
            displayMode: displayMode,
            language: language
        )
        let visibleEvents = validSelectedProjectID.map { projectID in
            toolVisibleEvents.filter { $0.event.projectID == projectID }
        } ?? toolVisibleEvents
        let toolFilterEvents = validSelectedProjectID.map { projectID in
            periodEvents.filter { $0.event.projectID == projectID }
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
        workflowUsage = Self.workflowUsage(events: focusedEvents, totalTokens: capturedTotalTokens, language: language)

        periodFilters = TokenUsageDashboardPeriod.allCases.map { period in
            let capturedPeriodTotal: Int
            if let total = periodFilterTotals?[period] {
                capturedPeriodTotal = total
            } else {
                let periodCapturedEvents = Self.filteredParsedEvents(
                    dashboardEvents,
                    selectedPeriod: period,
                    now: now,
                    calendar: calendar
                )
                capturedPeriodTotal = periodCapturedEvents.reduce(0) { $0 + $1.event.totalTokens }
            }
            return TokenUsageDashboardPeriodFilter(
                period: period,
                title: period.title(language: language),
                detail: Self.formatTokens(capturedPeriodTotal),
                isSelected: selectedDayID == nil && selectedPeriod == period
            )
        }

        let allToolTotals = Self.toolTotals(events: toolFilterEvents)
        toolFilters = Self.toolFilters(
            selectedTool: selectedDashboardTool,
            totals: allToolTotals,
            totalEvents: toolFilterEvents.count,
            showAdvancedTools: showAdvancedTools,
            displayMode: displayMode,
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

        toolRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: visibleCapturedToolTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let modelTokens = Self.tokenTotals(events: focusedEvents) { Self.modelKey($0.event.model) }
        modelRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: modelTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0 },
            label: { Self.modelLabel($0, language: language) }
        )

        let taskTokens = Self.tokenTotals(events: focusedEvents) { $0.event.taskType }
        taskRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: taskTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let stageTokens = Self.tokenTotals(events: focusedEvents) { $0.event.stage }
        stageRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: stageTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let sourceTokens = Self.sourceTotals(events: focusedEvents)
        sourceRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: sourceTokens,
            totalTokens: totalTokens,
            displayMode: displayMode,
            id: { $0.rawValue },
            label: { $0.label(language: language) }
        )

        sessions = sessionRows
        selectedSession = selectedSessionRow
        trendBuckets = TokenUsageDashboardTrendBucketBuilder.buckets(
            events: focusedEvents,
            selectedPeriod: selectedPeriod,
            language: language,
            now: now,
            periodOffset: periodOffset,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        // Comparison period tokens (nil when navigating to offset period, work item is selected, or period is .all)
        if selectedSessionRow != nil || selectedDayID != nil || periodOffset != 0 {
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
                let sevenDaysAgo = Self.periodStartDate(dayCount: 7, now: now, calendar: calendar)
                let fourteenDaysAgo = calendar.date(byAdding: .day, value: -7, to: sevenDaysAgo) ?? sevenDaysAgo
                let compEvents = toolFilteredEvents.filter { event in
                    guard let date = event.createdAt else { return false }
                    return date >= fourteenDaysAgo && date < sevenDaysAgo
                }
                comparisonTotalTokens = compEvents.isEmpty ? nil : compEvents.reduce(0) { $0 + $1.event.totalTokens }
            case .thirtyDays:
                let thirtyDaysAgo = Self.periodStartDate(dayCount: 30, now: now, calendar: calendar)
                let sixtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: thirtyDaysAgo) ?? thirtyDaysAgo
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

        if selectedDayID != nil {
            canNavigatePreviousPeriod = false
            canNavigateNextPeriod = false
        } else {
            let currentRange = Self.cutoffDateRange(for: selectedPeriod, periodOffset: periodOffset, now: now, calendar: calendar)
            let earliestDate = availableDateBounds?.earliest ?? dashboardEvents.compactMap(\.createdAt).min()
            if let earliestDate {
                if let currentStart = currentRange.start {
                    canNavigatePreviousPeriod = earliestDate < currentStart
                } else {
                    let nowYear = calendar.component(.year, from: now)
                    var currentYearComponents = DateComponents()
                    currentYearComponents.year = nowYear
                    currentYearComponents.month = 1
                    currentYearComponents.day = 1
                    currentYearComponents.hour = 0
                    currentYearComponents.minute = 0
                    currentYearComponents.second = 0
                    if let startOfCurrentYear = calendar.date(from: currentYearComponents) {
                        canNavigatePreviousPeriod = earliestDate < startOfCurrentYear
                    } else {
                        canNavigatePreviousPeriod = false
                    }
                }
            } else {
                canNavigatePreviousPeriod = false
            }
            canNavigateNextPeriod = periodOffset < 0
        }
    }

    private init(events: [TokenUsageEvent], selectedTool legacySelectedTool: TokenUsageAITool?) {
        self.init(events: events, selectedTool: legacySelectedTool, selectedPeriod: .all, selectedSessionID: nil, displayMode: .tokens)
    }

    static let empty = TokenUsageDashboardSnapshot(events: [])

    private struct LastUpdatedDates {
        var codex: Date?
        var claude: Date?
        var antigravity: Date?
        var overall: Date?
    }

    private static func lastUpdatedDates(in events: [TokenUsageDashboardParsedEvent]) -> LastUpdatedDates {
        var dates = LastUpdatedDates()

        for event in events {
            guard let createdAt = event.createdAt else {
                continue
            }

            dates.overall = laterDate(dates.overall, createdAt)
            switch event.event.aiTool {
            case .codex:
                dates.codex = laterDate(dates.codex, createdAt)
            case .claude:
                dates.claude = laterDate(dates.claude, createdAt)
            case .antigravity:
                dates.antigravity = laterDate(dates.antigravity, createdAt)
            default:
                break
            }
        }

        return dates
    }

    private static func laterDate(_ current: Date?, _ candidate: Date) -> Date {
        guard let current else {
            return candidate
        }

        return max(current, candidate)
    }

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

    static func formatCount(_ value: Int) -> String {
        NumberFormatter.tokenUsageFull.string(from: NSNumber(value: value)) ?? "\(value)"
    }

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

    static func cachedFixedDateFormatter(
        dateFormat: String,
        locale: Locale,
        timeZone: TimeZone
    ) -> DateFormatter {
        let key = "Spill.FixedFormatter.\(dateFormat).\(locale.identifier).\(timeZone.identifier)"
        if let formatter = Thread.current.threadDictionary[key] as? DateFormatter {
            return formatter
        }
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = locale
        formatter.timeZone = timeZone
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }

    static func cachedLocalizedDateFormatter(
        template: String,
        locale: Locale,
        timeZone: TimeZone
    ) -> DateFormatter {
        let key = "Spill.LocalizedFormatter.\(template).\(locale.identifier).\(timeZone.identifier)"
        if let formatter = Thread.current.threadDictionary[key] as? DateFormatter {
            return formatter
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        Thread.current.threadDictionary[key] = formatter
        return formatter
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

    static func formatPercentage(_ value: Double) -> String {
        if value > 0, value < 0.1 {
            return "<0.1%"
        }

        let number = NumberFormatter.tokenUsagePercentage.string(from: NSNumber(value: value))
            ?? String(format: "%.1f", value)
        return "\(number)%"
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

    private static func workflowUsage(
        events: [TokenUsageDashboardParsedEvent],
        totalTokens: Int,
        language: TokenMeteringLanguage
    ) -> TokenUsageDashboardWorkflowUsage {
        guard !events.isEmpty else {
            return TokenUsageDashboardWorkflowUsage(rows: [])
        }

        let assistedEvents = events.filter { event in
            TokenUsageWorkflowAssistance.isAssisted(event.event)
        }
        let assistedTokens = assistedEvents.reduce(0) { $0 + $1.event.totalTokens }
        let workRatio = chartRatio(tokens: assistedEvents.count, totalTokens: events.count)
        let tokenRatio = chartRatio(tokens: assistedTokens, totalTokens: totalTokens)

        return TokenUsageDashboardWorkflowUsage(rows: [
            TokenUsageDashboardBarRow(
                id: "work",
                title: TokenMeteringL10n.text(.workflowAssistedWork, language: language),
                value: formatPercentage(workRatio * 100.0),
                ratio: workRatio
            ),
            TokenUsageDashboardBarRow(
                id: "tokens",
                title: TokenMeteringL10n.text(.workflowAssistedTokens, language: language),
                value: formatPercentage(tokenRatio * 100.0),
                ratio: tokenRatio
            )
        ])
    }

    private static func toolFilters(
        selectedTool: TokenUsageAITool?,
        totals: [TokenUsageAITool: Int],
        totalEvents: Int,
        showAdvancedTools: Bool,
        displayMode: TokenUsageDisplayMode,
        language: TokenMeteringLanguage
    ) -> [TokenUsageDashboardToolFilter] {
        let allTotal = totals.values.reduce(0, +)
        let allFilterDetail = TokenMeteringL10n.eventsTokensDetail(
            eventCount: totalEvents,
            tokens: displayMode == .tokens ? formatTokens(allTotal) : formatPercentage(allTotal > 0 ? 100.0 : 0.0),
            language: language
        )
        let allFilter = TokenUsageDashboardToolFilter(
            tool: nil,
            title: TokenMeteringL10n.text(.allTools, language: language),
            detail: allFilterDetail,
            shareLabel: nil,
            isSelected: selectedTool == nil
        )
        let toolsToShow: [TokenUsageAITool] = showAdvancedTools
            ? TokenUsageAITool.allCases
            : TokenUsageAITool.dashboardTools
        let toolFilters = toolsToShow.map { tool in
            let tokens = totals[tool, default: 0]
            let ratio = TokenUsageDashboardSnapshot.chartRatio(
                tokens: tokens,
                totalTokens: allTotal
            )
            let detail: String
            let shareLabel: String?
            switch displayMode {
            case .tokens:
                detail = formatTokens(tokens)
                shareLabel = formatPercentage(ratio * 100.0)
            case .percentage:
                detail = formatPercentage(ratio * 100.0)
                shareLabel = formatTokens(tokens)
            }
            return TokenUsageDashboardToolFilter(
                tool: tool,
                title: tool.dashboardLabel(language: language),
                detail: detail,
                shareLabel: shareLabel,
                isSelected: selectedTool == tool
            )
        }

        return [allFilter] + toolFilters
    }

    private static func projectFilters(
        events: [TokenUsageDashboardParsedEvent],
        selectedProjectID: String?,
        displayMode: TokenUsageDisplayMode,
        language: TokenMeteringLanguage
    ) -> [TokenUsageDashboardProjectFilter] {
        let totalTokens = events.reduce(0) { $0 + $1.event.totalTokens }
        let allFilter = TokenUsageDashboardProjectFilter(
            projectID: nil,
            title: TokenMeteringL10n.text(.allFolders, language: language),
            detail: TokenMeteringL10n.eventsTokensDetail(
                eventCount: events.count,
                tokens: formatTokens(totalTokens),
                language: language
            ),
            isSelected: selectedProjectID == nil
        )
        let projectRows = Dictionary(grouping: events) { $0.event.projectID }
            .map { projectID, groupedEvents in
                let tokens = groupedEvents.reduce(0) { $0 + $1.event.totalTokens }
                let ratio = chartRatio(tokens: tokens, totalTokens: totalTokens)
                let value: String
                switch displayMode {
                case .tokens:
                    value = formatTokens(tokens)
                case .percentage:
                    value = formatPercentage(ratio * 100.0)
                }
                return TokenUsageDashboardProjectFilter(
                    projectID: projectID,
                    title: projectTitle(projectID, language: language),
                    detail: value,
                    isSelected: selectedProjectID == projectID
                )
            }
            .sorted { lhs, rhs in
                projectFilterPrecedes(lhs, rhs)
            }

        return [allFilter] + projectRows
    }

    private static func projectFilterPrecedes(
        _ lhs: TokenUsageDashboardProjectFilter,
        _ rhs: TokenUsageDashboardProjectFilter
    ) -> Bool {
        let lhsRank = lhs.projectID == "project_global" ? 0 : 1
        let rhsRank = rhs.projectID == "project_global" ? 0 : 1
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        if lhs.title != rhs.title {
            return lhs.title < rhs.title
        }
        return (lhs.projectID ?? "") < (rhs.projectID ?? "")
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
                    let pct = Self.chartRatio(tokens: totalT, totalTokens: totalTokens) * 100.0
                    valueStr = Self.formatPercentage(pct)
                }

                return (
                    row: TokenUsageDashboardSessionRow(
                        id: key.id,
                        runID: key.id,
                        projectID: key.projectID,
                        projectTitle: Self.projectTitle(key.projectID, language: language),
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

    static func projectTitle(_ projectID: String, language: TokenMeteringLanguage = .current()) -> String {
        guard projectID != "project_global" else {
            return TokenMeteringL10n.text(.folderUnassigned, language: language)
        }

        let rawID = projectID.hasPrefix("project_")
            ? String(projectID.dropFirst("project_".count))
            : projectID
        let shortID = String(rawID.prefix(8))
        guard !shortID.isEmpty else {
            return TokenMeteringL10n.text(.folderUnassigned, language: language)
        }
        return TokenMeteringL10n.folderTitle(shortID, language: language)
    }

    private static func workItemKey(
        for event: TokenUsageEvent,
        calendar: Calendar
    ) -> TokenUsageDashboardWorkItemKey {
        TokenUsageDashboardWorkItemKey(
            projectID: event.projectID,
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
            projectID: event.event.projectID,
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
                ratio: chartRatio(tokens: tokens, totalTokens: maxTokens),
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
