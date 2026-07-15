import Foundation

/// Builds the full TokenUsageDashboardSnapshot from SQL aggregate queries instead of a raw
/// events array, for the common case: no project/session/calendar-day drill-down selected, and
/// inputScope is .includeCache (the default). This is what lets the "All time" dashboard view
/// avoid loading and holding every stored event in memory just to answer aggregate totals.
///
/// Every field here mirrors TokenMeteringPresentationModel's private init exactly for this same
/// unfiltered/includeCache case; TokenUsageDashboardStore is responsible for falling back to the
/// existing events-based init(context:...) whenever a project/session/day is selected or
/// inputScope is .freshOnly (grouped fresh-token SQL sums don't exist yet).
extension TokenUsageDashboardSnapshot {
    static func buildFromSQLAggregates(
        usageStore: TokenUsageStore,
        selectedTool: TokenUsageAITool? = nil,
        selectedPeriod: TokenUsageDashboardPeriod = .all,
        language: TokenMeteringLanguage = .current(),
        localAliases: [String: String] = [:],
        showAdvancedTools: Bool = false,
        visibleTools: Set<TokenUsageAITool>? = nil,
        now: Date = Date(),
        calendarMonthStart: Date? = nil,
        periodOffset: Int = 0,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> TokenUsageDashboardSnapshot {
        let dashboardToolsOnly = !showAdvancedTools
        let selectedDashboardTool = selectedTool.flatMap { tool in
            tool.isDashboardTool && (visibleTools?.contains(tool) ?? true) ? tool : nil
        }
        // Combines the single selectedTool filter with the broader visibleTools set the same
        // way the events-based path's toolFilterEvents/toolVisibleEvents narrowing does.
        let effectiveVisibleTools = selectedDashboardTool.map { Set([$0]) } ?? visibleTools

        let requestRange = cutoffDateRange(for: selectedPeriod, periodOffset: periodOffset, now: now, calendar: calendar)
        let dateBounds = usageStore.dashboardDateBounds(
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        )
        // Period tabs always total across every visible tool, independent of which single tool
        // chip is currently selected -- matches the original init reading periodFilterTotals
        // (computed the same tool-unfiltered way) directly, with no selectedTool narrowing.
        let periodFilterTotals = usageStore.allPeriodInputScopeTotals(
            now: now,
            calendar: calendar,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        )

        let focused = usageStore.dashboardFocusedTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools
        )
        let eventCount = focused.eventCount
        let totalTokens = focused.totalTokens
        let inputTokens = focused.inputTokens
        let outputTokens = focused.outputTokens

        let kpis = [
            TokenUsageDashboardKPI(
                id: "total",
                title: TokenMeteringL10n.text(.totalTokens, language: language),
                value: formatTokens(totalTokens),
                detail: TokenMeteringL10n.localEventsDetail(eventCount: eventCount, language: language)
            ),
            TokenUsageDashboardKPI(
                id: "input",
                title: TokenMeteringL10n.text(.input, language: language),
                value: formatTokens(inputTokens),
                detail: percentageDetail(value: inputTokens, total: totalTokens, language: language)
            ),
            TokenUsageDashboardKPI(
                id: "output",
                title: TokenMeteringL10n.text(.output, language: language),
                value: formatTokens(outputTokens),
                detail: percentageDetail(value: outputTokens, total: totalTokens, language: language)
            )
        ]

        let periodFilters = TokenUsageDashboardPeriod.allCases.map { period -> TokenUsageDashboardPeriodFilter in
            let capturedPeriodTotal = periodFilterTotals[period]?.includeCache ?? 0
            return TokenUsageDashboardPeriodFilter(
                period: period,
                title: period.title(language: language),
                detail: formatTokens(capturedPeriodTotal),
                isSelected: selectedPeriod == period
            )
        }

        let toolTotals = usageStore.groupedTokenTotalsByTool(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        )
        // toolFilters' own totals/count intentionally ignore the single selectedTool narrowing
        // (only visibleTools) -- it needs the period+project scope shared by every tool chip,
        // not the one currently selected, matching how the original init's toolFilterEvents
        // (used for both allToolTotals and totalEvents here) is built from periodEvents without
        // any selectedTool filter applied.
        let toolFilterScopeEventCount = usageStore.dashboardFocusedTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        ).eventCount
        let toolFilters = Self.toolFilters(
            selectedTool: selectedDashboardTool,
            totals: toolTotals,
            totalEvents: toolFilterScopeEventCount,
            showAdvancedTools: showAdvancedTools,
            visibleTools: visibleTools,
            language: language
        )

        let projectTotals = usageStore.groupedProjectTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools
        )
        let projectFilters = Self.projectFiltersFromTotals(projectTotals, selectedProjectID: nil, language: language)

        let inputAccountingSQL = usageStore.inputAccountingTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools
        )
        var accountingTotals = [TokenUsageInputAccountingCategory: Int]()
        for (key, value) in inputAccountingSQL {
            guard let category = TokenUsageInputAccountingCategory(rawValue: key) else { continue }
            accountingTotals[category] = value
        }
        let inputAccountingRows = TokenUsageDashboardRowBuilder.rows(
            candidates: TokenUsageInputAccountingCategory.allCases,
            totalTokens: inputTokens,
            tokens: { accountingTotals[$0, default: 0] },
            id: { $0.rawValue },
            label: { $0.label(language: language) }
        )
        let inputAccounting = TokenUsageDashboardInputAccounting(
            rows: inputAccountingRows,
            rawInputTokens: inputTokens,
            exactFreshInputTokens: accountingTotals[.uncachedInput, default: 0]
        )

        // Unlike toolFilters' totals (deliberately unfiltered by selectedTool), toolRows must
        // reflect the fully-focused scope -- selectedTool narrowing included -- matching the
        // original init's visibleCapturedToolTokens, which is built from focusedEvents.
        let toolRowTotals = usageStore.groupedTokenTotalsByTool(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools
        )
        let toolRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: toolRowTotals.filter { tool, _ in visibleTools?.contains(tool) ?? true },
            totalTokens: totalTokens,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let modelTotalsSQL = usageStore.groupedModelTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools
        )
        let modelRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: modelTotalsSQL,
            totalTokens: totalTokens,
            id: { $0 },
            label: { modelLabel($0, language: language) }
        )

        let taskTotalsSQL = usageStore.groupedTaskTypeTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools
        )
        var taskTotals = [TokenUsageTaskType: Int]()
        for (key, value) in taskTotalsSQL {
            taskTotals[TokenUsageTaskType(rawValue: key) ?? .uncategorized, default: 0] += value
        }
        let taskRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: taskTotals,
            totalTokens: totalTokens,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let stageTotalsSQL = usageStore.groupedStageTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools
        )
        var stageTotals = [TokenUsageStage: Int]()
        for (key, value) in stageTotalsSQL {
            stageTotals[TokenUsageStage(rawValue: key) ?? .summarize, default: 0] += value
        }
        let stageRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: stageTotals,
            totalTokens: totalTokens,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let sourceTotalsSQL = usageStore.sourceTokenTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools
        )
        var sourceTotals = [TokenUsageSource: Int]()
        for (key, value) in sourceTotalsSQL {
            guard let source = TokenUsageSource(rawValue: key) else { continue }
            sourceTotals[source] = value
        }
        let sourceRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: sourceTotals,
            totalTokens: totalTokens,
            id: { $0.rawValue },
            label: { $0.label(language: language) }
        )

        let workflowUsage: TokenUsageDashboardWorkflowUsage
        if eventCount == 0 {
            workflowUsage = TokenUsageDashboardWorkflowUsage(rows: [])
        } else {
            let workRatio = chartRatio(tokens: focused.assistedEventCount, totalTokens: eventCount)
            let tokenRatio = chartRatio(tokens: focused.assistedTotalTokens, totalTokens: totalTokens)
            workflowUsage = TokenUsageDashboardWorkflowUsage(rows: [
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

        let sourceRowsData = usageStore.sessionSourceRows(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools,
            selectedTool: nil,
            projectID: nil,
            calendar: calendar
        )
        let sessions = sessionRows(
            sourceRows: sourceRowsData,
            inputScope: .includeCache,
            language: language,
            localAliases: localAliases,
            calendar: calendar,
            now: now,
            locale: locale,
            timeZone: timeZone
        )

        // Bounded to requestRange, matching what focusedEvents (period-filtered) would contain
        // in the original: an unbounded fetch would let out-of-window rows (e.g. an old month
        // while viewing "7 days") leak into the per-bucket max() used for chart ratios, even
        // though those rows are never actually rendered as a bucket.
        let trendRows = usageStore.trendSourceRows(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools,
            calendar: calendar
        )
        let trendBuckets = TokenUsageDashboardTrendBucketBuilder.buckets(
            sourceRows: trendRows,
            selectedPeriod: selectedPeriod,
            language: language,
            now: now,
            periodOffset: periodOffset,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone,
            visibleTools: visibleTools
        )

        let comparisonTotalTokens: Int?
        if periodOffset != 0 {
            comparisonTotalTokens = nil
        } else {
            comparisonTotalTokens = Self.comparisonTotal(
                usageStore: usageStore,
                selectedPeriod: selectedPeriod,
                now: now,
                calendar: calendar,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: effectiveVisibleTools
            )
        }

        let todayCalendarDayID = dayID(for: now, calendar: calendar)
        let calendarMonth = calendarMonthStart ?? normalizedCalendarMonthStart(
            availableDateBounds: dateBounds,
            now: now,
            proposedMonthStart: calendarMonthStart,
            calendar: calendar
        )
        let firstDataMonth = dateBounds.earliest.map { monthStart(for: $0, calendar: calendar) } ?? monthStart(for: now, calendar: calendar)
        let currentMonth = monthStart(for: now, calendar: calendar)
        let calendarMonthTitle = formatCalendarMonth(calendarMonth, locale: locale, timeZone: timeZone)
        let calendarWeekdayTitles = weekdayTitles(locale: locale)
        let canNavigatePreviousCalendarMonth = calendar.compare(calendarMonth, to: firstDataMonth, toGranularity: .month) == .orderedDescending
        let canNavigateNextCalendarMonth = calendar.compare(calendarMonth, to: currentMonth, toGranularity: .month) == .orderedAscending
        // Like periodFilters, the calendar heatmap totals are deliberately unfiltered by the
        // single selectedTool -- only by the broader visibleTools set -- matching how the
        // buildPair caller computes calendarDayTotals independent of selectedTool.
        let calendarDayTotals = usageStore.dashboardDayTokenTotals(
            startingAt: calendarMonth,
            endingBefore: calendar.date(byAdding: .month, value: 1, to: calendarMonth) ?? calendarMonth,
            calendar: calendar,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        )
        let calendarDays = Self.calendarDays(
            events: [],
            monthStart: calendarMonth,
            selectedCalendarDayID: nil,
            todayCalendarDayID: todayCalendarDayID,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone,
            dayTokenTotals: calendarDayTotals,
            rawDayTokenTotals: calendarDayTotals
        )

        let lastUpdated = usageStore.lastUpdatedByTool(
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        )
        let overallLastUpdated = lastUpdated.values.max()

        let canNavigatePreviousPeriod: Bool
        let canNavigateNextPeriod: Bool
        if let earliestDate = dateBounds.earliest {
            if let currentStart = requestRange.start {
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
            canNavigateNextPeriod = periodOffset < 0
        } else {
            canNavigatePreviousPeriod = false
            canNavigateNextPeriod = false
        }

        return TokenUsageDashboardSnapshot(
            eventCount: eventCount,
            totalTokens: totalTokens,
            kpis: kpis,
            periodFilters: periodFilters,
            toolFilters: toolFilters,
            projectFilters: projectFilters,
            selectedProjectID: nil,
            toolRows: toolRows,
            modelRows: modelRows,
            workflowUsage: workflowUsage,
            inputAccounting: inputAccounting,
            taskRows: taskRows,
            stageRows: stageRows,
            sourceRows: sourceRows,
            sessions: sessions,
            selectedSession: nil,
            trendBuckets: trendBuckets,
            calendarDays: calendarDays,
            calendarMonthTitle: calendarMonthTitle,
            calendarWeekdayTitles: calendarWeekdayTitles,
            selectedCalendarDayID: nil,
            selectedCalendarDayTitle: nil,
            todayCalendarDayID: todayCalendarDayID,
            todayCalendarDayTitle: formatCalendarDayTitle(now, locale: locale, timeZone: timeZone),
            canNavigatePreviousCalendarMonth: canNavigatePreviousCalendarMonth,
            canNavigateNextCalendarMonth: canNavigateNextCalendarMonth,
            codexLastUpdated: lastUpdated[.codex],
            claudeLastUpdated: lastUpdated[.claude],
            antigravityLastUpdated: lastUpdated[.antigravity],
            overallLastUpdated: overallLastUpdated,
            codexLastUpdatedString: lastUpdated[.codex].map {
                formatLocalTimestamp($0, now: now, calendar: calendar, locale: locale, timeZone: timeZone)
            },
            claudeLastUpdatedString: lastUpdated[.claude].map {
                formatLocalTimestamp($0, now: now, calendar: calendar, locale: locale, timeZone: timeZone)
            },
            antigravityLastUpdatedString: lastUpdated[.antigravity].map {
                formatLocalTimestamp($0, now: now, calendar: calendar, locale: locale, timeZone: timeZone)
            },
            overallLastUpdatedString: overallLastUpdated.map {
                formatLocalTimestamp($0, now: now, calendar: calendar, locale: locale, timeZone: timeZone)
            },
            comparisonTotalTokens: comparisonTotalTokens,
            canNavigatePreviousPeriod: canNavigatePreviousPeriod,
            canNavigateNextPeriod: canNavigateNextPeriod
        )
    }
}

private extension TokenUsageDashboardSnapshot {
    static func comparisonTotal(
        usageStore: TokenUsageStore,
        selectedPeriod: TokenUsageDashboardPeriod,
        now: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>?
    ) -> Int? {
        switch selectedPeriod {
        case .today:
            let todayStart = calendar.startOfDay(for: now)
            let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            return usageStore.comparisonTokenTotal(
                startingAt: yesterdayStart,
                endingBefore: todayStart,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools
            )
        case .sevenDays:
            let sevenDaysAgo = periodStartDate(dayCount: 7, now: now, calendar: calendar)
            let fourteenDaysAgo = calendar.date(byAdding: .day, value: -7, to: sevenDaysAgo) ?? sevenDaysAgo
            return usageStore.comparisonTokenTotal(
                startingAt: fourteenDaysAgo,
                endingBefore: sevenDaysAgo,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools
            )
        case .thirtyDays:
            let thirtyDaysAgo = periodStartDate(dayCount: 30, now: now, calendar: calendar)
            let sixtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: thirtyDaysAgo) ?? thirtyDaysAgo
            return usageStore.comparisonTokenTotal(
                startingAt: sixtyDaysAgo,
                endingBefore: thirtyDaysAgo,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools
            )
        case .all:
            return nil
        }
    }

    /// Mirrors TokenUsageDashboardSnapshot.projectFilters(events:...), but built directly from
    /// pre-grouped SQL totals instead of grouping raw events.
    static func projectFiltersFromTotals(
        _ totals: [String: (eventCount: Int, totals: TokenUsageInputScopeTotals)],
        selectedProjectID: String?,
        language: TokenMeteringLanguage
    ) -> [TokenUsageDashboardProjectFilter] {
        let totalTokens = totals.values.reduce(0) { $0 + $1.totals.includeCache }
        let totalEvents = totals.values.reduce(0) { $0 + $1.eventCount }
        let allFilter = TokenUsageDashboardProjectFilter(
            projectID: nil,
            title: TokenMeteringL10n.text(.allFolders, language: language),
            detail: TokenMeteringL10n.eventsTokensDetail(
                eventCount: totalEvents,
                tokens: formatTokens(totalTokens),
                language: language
            ),
            isSelected: selectedProjectID == nil
        )
        let projectRows = totals.map { projectID, value in
            TokenUsageDashboardProjectFilter(
                projectID: projectID,
                title: projectTitle(projectID, language: language),
                detail: formatTokens(value.totals.includeCache),
                isSelected: selectedProjectID == projectID
            )
        }.sorted { lhs, rhs in
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

        return [allFilter] + projectRows
    }
}
