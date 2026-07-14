import Foundation

struct TokenUsageDashboardSnapshot: Equatable {
    let eventCount: Int
    let totalTokens: Int
    let kpis: [TokenUsageDashboardKPI]
    let periodFilters: [TokenUsageDashboardPeriodFilter]
    let toolFilters: [TokenUsageDashboardToolFilter]
    let projectFilters: [TokenUsageDashboardProjectFilter]
    let selectedProjectID: String?
    let toolRows: [TokenUsageDashboardBarRow]
    let modelRows: [TokenUsageDashboardBarRow]
    let workflowUsage: TokenUsageDashboardWorkflowUsage
    let inputAccounting: TokenUsageDashboardInputAccounting
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

    private init(
        context: TokenUsageDashboardSnapshotBuildContext,
        selectedTool: TokenUsageAITool? = nil,
        selectedPeriod: TokenUsageDashboardPeriod = .all,
        selectedCalendarDayID: String? = nil,
        selectedProjectID: String? = nil,
        selectedSessionID: String? = nil,
        language: TokenMeteringLanguage = .current(),
        localAliases: [String: String] = [:],
        showAdvancedTools: Bool = false,
        visibleTools: Set<TokenUsageAITool>? = nil,
        now: Date = Date(),
        calendarMonthStart: Date? = nil,
        resolvedCalendarMonthStart: Date? = nil,
        periodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals]? = nil,
        availableDateBounds: TokenUsageDashboardDateBounds? = nil,
        periodOffset: Int = 0,
        inputScope: TokenUsageInputScope = .includeCache,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        calendarDayTotals: [String: TokenUsageInputScopeTotals]? = nil
    ) {
        let dashboardEvents = context.dashboardEvents.filter { event in
            visibleTools?.contains(event.event.aiTool) ?? true
        }
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
            tool.isDashboardTool && (visibleTools?.contains(tool) ?? true) ? tool : nil
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
            inputScope: inputScope,
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
        var capturedTotalTokens = 0
        var capturedUsageTokens = 0
        for focusedEvent in focusedEvents {
            capturedTotalTokens += focusedEvent.event.totalTokens
            capturedUsageTokens += Self.usageTokens(for: focusedEvent.event, inputScope: inputScope)
        }
        totalTokens = capturedTotalTokens
        let visibleCapturedToolTokens = Self.toolTotals(
            events: focusedEvents,
            inputScope: inputScope
        )
            .filter { tool, _ in
                visibleTools?.contains(tool) ?? true
            }
        workflowUsage = Self.workflowUsage(events: focusedEvents, totalTokens: capturedTotalTokens, language: language)

        periodFilters = TokenUsageDashboardPeriod.allCases.map { period in
            let capturedPeriodTotal: Int
            if let totals = periodFilterTotals?[period] {
                capturedPeriodTotal = totals.total(for: inputScope)
            } else {
                let periodCapturedEvents = Self.filteredParsedEvents(
                    dashboardEvents,
                    selectedPeriod: period,
                    now: now,
                    calendar: calendar
                )
                capturedPeriodTotal = periodCapturedEvents.reduce(0) {
                    $0 + Self.usageTokens(for: $1.event, inputScope: inputScope)
                }
            }
            return TokenUsageDashboardPeriodFilter(
                period: period,
                title: period.title(language: language),
                detail: Self.formatTokens(capturedPeriodTotal),
                isSelected: selectedDayID == nil && selectedPeriod == period
            )
        }

        let allToolTotals = Self.toolTotals(
            events: toolFilterEvents,
            inputScope: inputScope
        )
        toolFilters = Self.toolFilters(
            selectedTool: selectedDashboardTool,
            totals: allToolTotals,
            totalEvents: toolFilterEvents.count,
            showAdvancedTools: showAdvancedTools,
            visibleTools: visibleTools,
            language: language
        )

        let inputTokens = focusedEvents.reduce(0) { $0 + $1.event.inputTokens }
        let outputTokens = focusedEvents.reduce(0) { $0 + $1.event.outputTokens }
        inputAccounting = Self.inputAccounting(
            events: focusedEvents,
            inputTokens: inputTokens,
            language: language
        )

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

        toolRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: visibleCapturedToolTokens,
            totalTokens: capturedUsageTokens,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let modelTokens = Self.tokenTotals(events: focusedEvents, inputScope: inputScope) {
            Self.modelKey($0.event.model)
        }
        modelRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: modelTokens,
            totalTokens: capturedUsageTokens,
            id: { $0 },
            label: { Self.modelLabel($0, language: language) }
        )

        let taskTokens = Self.tokenTotals(events: focusedEvents) { $0.event.taskType }
        taskRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: taskTokens,
            totalTokens: totalTokens,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let stageTokens = Self.tokenTotals(events: focusedEvents) { $0.event.stage }
        stageRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: stageTokens,
            totalTokens: totalTokens,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let sourceTokens = Self.sourceTotals(events: focusedEvents)
        sourceRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: sourceTokens,
            totalTokens: totalTokens,
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
            timeZone: timeZone,
            inputScope: inputScope,
            visibleTools: visibleTools
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
                comparisonTotalTokens = compEvents.isEmpty ? nil : compEvents.reduce(0) {
                    $0 + Self.usageTokens(for: $1.event, inputScope: inputScope)
                }
            case .sevenDays:
                let sevenDaysAgo = Self.periodStartDate(dayCount: 7, now: now, calendar: calendar)
                let fourteenDaysAgo = calendar.date(byAdding: .day, value: -7, to: sevenDaysAgo) ?? sevenDaysAgo
                let compEvents = toolFilteredEvents.filter { event in
                    guard let date = event.createdAt else { return false }
                    return date >= fourteenDaysAgo && date < sevenDaysAgo
                }
                comparisonTotalTokens = compEvents.isEmpty ? nil : compEvents.reduce(0) {
                    $0 + Self.usageTokens(for: $1.event, inputScope: inputScope)
                }
            case .thirtyDays:
                let thirtyDaysAgo = Self.periodStartDate(dayCount: 30, now: now, calendar: calendar)
                let sixtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: thirtyDaysAgo) ?? thirtyDaysAgo
                let compEvents = toolFilteredEvents.filter { event in
                    guard let date = event.createdAt else { return false }
                    return date >= sixtyDaysAgo && date < thirtyDaysAgo
                }
                comparisonTotalTokens = compEvents.isEmpty ? nil : compEvents.reduce(0) {
                    $0 + Self.usageTokens(for: $1.event, inputScope: inputScope)
                }
            case .all:
                comparisonTotalTokens = nil
            }
        }

        let selectedDayMonth = selectedDayID
            .flatMap { Self.date(forDayID: $0, calendar: calendar) }
            .map { Self.monthStart(for: $0, calendar: calendar) }
        let calendarMonth = resolvedCalendarMonthStart ?? Self.normalizedCalendarMonthStart(
            events: dashboardEvents,
            availableDateBounds: availableDateBounds,
            now: now,
            proposedMonthStart: calendarMonthStart ?? selectedDayMonth,
            calendar: calendar
        )
        let firstDataMonth = availableDateBounds?.earliest
            .map { Self.monthStart(for: $0, calendar: calendar) }
            ?? Self.firstDataMonthStart(events: dashboardEvents, now: now, calendar: calendar)
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
            timeZone: timeZone,
            dayTokenTotals: calendarDayTotals?.mapValues { $0.total(for: inputScope) },
            rawDayTokenTotals: calendarDayTotals?.mapValues(\.includeCache)
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

}

extension TokenUsageDashboardSnapshot {
    var usageInputScopeTotals: TokenUsageInputScopeTotals {
        TokenUsageInputScopeTotals(
            totalTokens: totalTokens,
            rawInputTokens: inputAccounting.rawInputTokens,
            exactFreshInputTokens: inputAccounting.exactFreshInputTokens
        )
    }

    func usageKPIs(
        for scope: TokenUsageInputScope,
        language: TokenMeteringLanguage
    ) -> [TokenUsageDashboardKPI] {
        guard scope == .freshOnly else {
            return kpis
        }

        let outputTokens = max(0, totalTokens - inputAccounting.rawInputTokens)
        let freshInputTokens = inputAccounting.exactFreshInputTokens
        let freshTotalTokens = usageInputScopeTotals.freshOnly

        return [
            TokenUsageDashboardKPI(
                id: "total",
                title: TokenMeteringL10n.text(.totalTokens, language: language),
                value: Self.formatTokens(freshTotalTokens),
                detail: TokenMeteringL10n.localEventsDetail(eventCount: eventCount, language: language)
            ),
            TokenUsageDashboardKPI(
                id: "input",
                title: TokenMeteringL10n.text(.input, language: language),
                value: Self.formatTokens(freshInputTokens),
                detail: Self.percentageDetail(value: freshInputTokens, total: freshTotalTokens, language: language)
            ),
            TokenUsageDashboardKPI(
                id: "output",
                title: TokenMeteringL10n.text(.output, language: language),
                value: Self.formatTokens(outputTokens),
                detail: Self.percentageDetail(value: outputTokens, total: freshTotalTokens, language: language)
            )
        ]
    }

    static func buildPair(
        events: [TokenUsageEvent],
        selectedTool: TokenUsageAITool?,
        selectedPeriod: TokenUsageDashboardPeriod,
        selectedCalendarDayID: String?,
        selectedProjectID: String?,
        selectedSessionID: String?,
        language: TokenMeteringLanguage,
        localAliases: [String: String],
        showAdvancedTools: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        now: Date,
        proposedCalendarMonthStart: Date?,
        calendar: Calendar,
        periodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals]? = nil,
        availableDateBounds: TokenUsageDashboardDateBounds? = nil,
        calendarDayTotals: [String: TokenUsageInputScopeTotals]? = nil,
        periodOffset: Int = 0,
        inputScope: TokenUsageInputScope = .includeCache,
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
            language: language,
            localAliases: localAliases,
            showAdvancedTools: showAdvancedTools,
            visibleTools: visibleTools,
            now: now,
            proposedCalendarMonthStart: proposedCalendarMonthStart,
            calendar: calendar,
            periodFilterTotals: periodFilterTotals,
            availableDateBounds: availableDateBounds,
            calendarDayTotals: calendarDayTotals,
            periodOffset: periodOffset,
            inputScope: inputScope,
            locale: locale,
            timeZone: timeZone
        )
    }

}

extension TokenUsageDashboardSnapshot {
    static func buildPair(
        context: TokenUsageDashboardSnapshotBuildContext,
        selectedTool: TokenUsageAITool?,
        selectedPeriod: TokenUsageDashboardPeriod,
        selectedCalendarDayID: String?,
        selectedProjectID: String?,
        selectedSessionID: String?,
        language: TokenMeteringLanguage,
        localAliases: [String: String],
        showAdvancedTools: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        now: Date,
        proposedCalendarMonthStart: Date?,
        calendar: Calendar,
        periodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals]? = nil,
        availableDateBounds: TokenUsageDashboardDateBounds? = nil,
        calendarDayTotals: [String: TokenUsageInputScopeTotals]? = nil,
        periodOffset: Int = 0,
        inputScope: TokenUsageInputScope = .includeCache,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> TokenUsageDashboardSnapshotPair {
        let selectedDayMonth = selectedCalendarDayID
            .flatMap { date(forDayID: $0, calendar: calendar) }
            .map { monthStart(for: $0, calendar: calendar) }
        let displayCalendarMonth = normalizedCalendarMonthStart(
            events: context.dashboardEvents,
            availableDateBounds: availableDateBounds,
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
            language: language,
            localAliases: localAliases,
            showAdvancedTools: showAdvancedTools,
            visibleTools: visibleTools,
            now: now,
            calendarMonthStart: displayCalendarMonth,
            resolvedCalendarMonthStart: displayCalendarMonth,
            periodFilterTotals: periodFilterTotals,
            availableDateBounds: availableDateBounds,
            periodOffset: periodOffset,
            inputScope: inputScope,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone,
            calendarDayTotals: calendarDayTotals
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
                language: language,
                localAliases: localAliases,
                showAdvancedTools: showAdvancedTools,
                visibleTools: visibleTools,
                now: now,
                calendarMonthStart: displayCalendarMonth,
                resolvedCalendarMonthStart: displayCalendarMonth,
                periodFilterTotals: periodFilterTotals,
                availableDateBounds: availableDateBounds,
                periodOffset: periodOffset,
                inputScope: inputScope,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone,
                calendarDayTotals: calendarDayTotals
            )

        return TokenUsageDashboardSnapshotPair(
            filtered: filtered,
            unfiltered: unfiltered,
            calendarMonthStart: displayCalendarMonth
        )
    }

}

extension TokenUsageDashboardSnapshot {
    init(
        events: [TokenUsageEvent],
        selectedTool: TokenUsageAITool? = nil,
        selectedPeriod: TokenUsageDashboardPeriod = .all,
        selectedCalendarDayID: String? = nil,
        selectedProjectID: String? = nil,
        selectedSessionID: String? = nil,
        language: TokenMeteringLanguage = .current(),
        localAliases: [String: String] = [:],
        showAdvancedTools: Bool = false,
        visibleTools: Set<TokenUsageAITool>? = nil,
        now: Date = Date(),
        calendarMonthStart: Date? = nil,
        periodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals]? = nil,
        availableDateBounds: TokenUsageDashboardDateBounds? = nil,
        periodOffset: Int = 0,
        inputScope: TokenUsageInputScope = .includeCache,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        calendarDayTotals: [String: TokenUsageInputScopeTotals]? = nil
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
            language: language,
            localAliases: localAliases,
            showAdvancedTools: showAdvancedTools,
            visibleTools: visibleTools,
            now: now,
            calendarMonthStart: calendarMonthStart,
            resolvedCalendarMonthStart: nil,
            periodFilterTotals: periodFilterTotals,
            availableDateBounds: availableDateBounds,
            periodOffset: periodOffset,
            inputScope: inputScope,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone,
            calendarDayTotals: calendarDayTotals
        )
    }

}

extension TokenUsageDashboardSnapshot {
    private init(events: [TokenUsageEvent], selectedTool legacySelectedTool: TokenUsageAITool?) {
        self.init(events: events, selectedTool: legacySelectedTool, selectedPeriod: .all, selectedSessionID: nil)
    }

    static let empty = TokenUsageDashboardSnapshot(events: [])
}
