import Foundation

/// Builds the full TokenUsageDashboardSnapshot from SQL aggregate queries instead of a raw
/// events array, for the common case: no project/session/calendar-day drill-down selected. Both
/// .includeCache and .freshOnly inputScope are SQL-eligible. This is what lets the "All time"
/// dashboard view avoid loading and holding every stored event in memory just to answer
/// aggregate totals.
///
/// Every field here mirrors TokenMeteringPresentationModel's private init exactly for this same
/// unfiltered case; TokenUsageDashboardStore is responsible for falling back to the existing
/// events-based init(context:...) whenever a project/session/day is selected.
///
/// A nil return always means "could not read right now" -- the shared connection failed to open,
/// or any one statement in the batch failed to prepare or step (see TokenUsageQueryFailureObserver).
/// It never means "no data": an empty store reads back a non-nil empty snapshot. Callers rely on
/// that distinction to keep showing the last known-good snapshot on a transient failure instead of
/// overwriting it with a blank one.
extension TokenUsageDashboardSnapshot {
    static func buildFromSQLAggregates(
        usageStore: TokenUsageStore,
        selectedTool: TokenUsageAITool? = nil,
        selectedPeriod: TokenUsageDashboardPeriod = .all,
        inputScope: TokenUsageInputScope = .includeCache,
        language: TokenMeteringLanguage = .current(),
        localAliases: [String: String] = [:],
        showAdvancedTools: Bool = false,
        visibleTools: Set<TokenUsageAITool>? = nil,
        now: Date = Date(),
        calendarMonthStart: Date? = nil,
        periodOffset: Int = 0,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        database: OpaquePointer? = nil
    ) -> TokenUsageDashboardSnapshot? {
        let dashboardToolsOnly = !showAdvancedTools
        let selectedDashboardTool = selectedTool.flatMap { tool in
            tool.isDashboardTool && (visibleTools?.contains(tool) ?? true) ? tool : nil
        }
        // Combines the single selectedTool filter with the broader visibleTools set the same
        // way the events-based path's toolFilterEvents/toolVisibleEvents narrowing does.
        let effectiveVisibleTools = selectedDashboardTool.map { Set([$0]) } ?? visibleTools

        let requestRange = cutoffDateRange(for: selectedPeriod, periodOffset: periodOffset, now: now, calendar: calendar)

        // Every aggregate read below shares this one connection instead of each of the ~19
        // calls independently opening/closing its own: that used to mean one refresh could see
        // up to ~19 (or ~38, when a tool filter forces a filtered+unfiltered pass) independent
        // chances for a transient open failure to silently zero just that field, and no
        // guarantee the fields it did get were read from the same point-in-time view of the
        // database under concurrent writes from the importer process. Sharing one connection
        // (wrapped in a read transaction, see withDatabaseConnection) collapses that down to a
        // single open and a consistent read for the whole snapshot. If the shared connection
        // can't be opened at all, this returns nil instead of an empty snapshot: a nil here is
        // what lets the caller (buildSnapshotOutputFromSQL) tell "genuinely nothing to show" and
        // "couldn't read right now" apart, and keep showing the last known-good snapshot for the
        // latter instead of overwriting it with a blank one.
        //
        // When `database` is non-nil the caller owns both the connection and its transaction (the
        // filtered+unfiltered pair reads the same WAL snapshot); withDatabaseConnection then runs
        // the body directly on it without opening or nesting anything. The failureObserver extends
        // the same fail-closed contract past connection open: any single statement that fails to
        // prepare or step marks it, and the guard below discards the whole (partially-defaulted)
        // snapshot rather than publishing zeros for the fields that silently defaulted.
        let failureObserver = TokenUsageQueryFailureObserver()
        return usageStore.withDatabaseConnection(database, default: nil) { database in
        let dateBounds = usageStore.dashboardDateBounds(
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        )
        // Period tabs always total across every visible tool, independent of which single tool
        // chip is currently selected -- matches the original init reading periodFilterTotals
        // (computed the same tool-unfiltered way) directly, with no selectedTool narrowing.
        let periodFilterTotals = usageStore.allPeriodInputScopeTotals(
            now: now,
            calendar: calendar,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        )

        let focused = usageStore.dashboardFocusedTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools,
            database: database,
            failureObserver: failureObserver
        )
        let eventCount = focused.eventCount
        let totalTokens = focused.totalTokens
        let inputTokens = focused.inputTokens
        let outputTokens = focused.outputTokens
        // Mirrors the original init's capturedUsageTokens: raw totalTokens for .includeCache,
        // the exact fresh (output + uncached input) sum for .freshOnly. Used as the denominator
        // for tool/model/task/stage rows -- unlike the totalTokens KPI, which always stays raw.
        let usageTokensTotal = inputScope == .includeCache ? totalTokens : focused.exactFreshTotalTokens

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
            let capturedPeriodTotal = periodFilterTotals[period]?.total(for: inputScope) ?? 0
            return TokenUsageDashboardPeriodFilter(
                period: period,
                title: period.title(language: language),
                detail: formatTokens(capturedPeriodTotal),
                isSelected: selectedPeriod == period
            )
        }

        let toolTotals = usageStore.groupedInputScopeTotalsByTool(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        ).mapValues { $0.total(for: inputScope) }
        // toolFilters' own totals/count intentionally ignore the single selectedTool narrowing
        // (only visibleTools) -- it needs the period+project scope shared by every tool chip,
        // not the one currently selected, matching how the original init's toolFilterEvents
        // (used for both allToolTotals and totalEvents here) is built from periodEvents without
        // any selectedTool filter applied.
        let toolFilterScopeEventCount = usageStore.dashboardFocusedTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
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
            visibleTools: effectiveVisibleTools,
            database: database,
            failureObserver: failureObserver
        )
        let projectFilters = Self.projectFiltersFromTotals(
            projectTotals,
            selectedProjectID: nil,
            inputScope: inputScope,
            language: language
        )

        let inputAccountingSQL = usageStore.inputAccountingTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools,
            database: database,
            failureObserver: failureObserver
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
        let toolRowTotals = usageStore.groupedInputScopeTotalsByTool(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools,
            database: database,
            failureObserver: failureObserver
        ).mapValues { $0.total(for: inputScope) }
        let toolRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: toolRowTotals.filter { tool, _ in visibleTools?.contains(tool) ?? true },
            totalTokens: usageTokensTotal,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let modelTotalsSQL = usageStore.groupedModelInputScopeTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools,
            database: database,
            failureObserver: failureObserver
        ).mapValues { $0.total(for: inputScope) }
        let modelRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: modelTotalsSQL,
            totalTokens: usageTokensTotal,
            id: { $0 },
            label: { modelLabel($0, language: language) }
        )

        let taskTotalsSQL = usageStore.groupedTaskTypeInputScopeTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools,
            database: database,
            failureObserver: failureObserver
        )
        var taskTotals = [TokenUsageTaskType: Int]()
        for (key, value) in taskTotalsSQL {
            taskTotals[TokenUsageTaskType(rawValue: key) ?? .uncategorized, default: 0] += value.total(for: inputScope)
        }
        let taskRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: taskTotals,
            totalTokens: usageTokensTotal,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let stageTotalsSQL = usageStore.groupedStageInputScopeTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools,
            database: database,
            failureObserver: failureObserver
        )
        var stageTotals = [TokenUsageStage: Int]()
        for (key, value) in stageTotalsSQL {
            stageTotals[TokenUsageStage(rawValue: key) ?? .summarize, default: 0] += value.total(for: inputScope)
        }
        let stageRows = TokenUsageDashboardRowBuilder.rows(
            tokenValues: stageTotals,
            totalTokens: usageTokensTotal,
            id: { $0.rawValue },
            label: { $0.dashboardLabel(language: language) }
        )

        let sourceTotalsSQL = usageStore.sourceTokenTotals(
            startingAt: requestRange.start,
            endingBefore: requestRange.end,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: effectiveVisibleTools,
            database: database,
            failureObserver: failureObserver
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
            calendar: calendar,
            database: database,
            failureObserver: failureObserver
        )
        let sessions = sessionRows(
            sourceRows: sourceRowsData,
            inputScope: inputScope,
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
            calendar: calendar,
            database: database,
            failureObserver: failureObserver
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
            inputScope: inputScope,
            visibleTools: visibleTools
        )

        let comparisonTotalTokens: Int?
        if periodOffset != 0 {
            comparisonTotalTokens = nil
        } else {
            comparisonTotalTokens = Self.comparisonTotal(
                usageStore: usageStore,
                selectedPeriod: selectedPeriod,
                inputScope: inputScope,
                now: now,
                calendar: calendar,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: effectiveVisibleTools,
                database: database,
                failureObserver: failureObserver
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
        let calendarDayTotals = usageStore.dashboardDayInputScopeTotals(
            startingAt: calendarMonth,
            endingBefore: calendar.date(byAdding: .month, value: 1, to: calendarMonth) ?? calendarMonth,
            calendar: calendar,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        ).mapValues { $0.total(for: inputScope) }
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
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
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

        // Any statement above that failed to prepare or step silently returned its empty default,
        // leaving a snapshot that mixes real fields with zeroed ones. Discard the whole thing so
        // buildSnapshotOutputFromSQL keeps the last known-good snapshot instead of publishing that
        // partial blank -- the same fail-closed contract as a connection that never opened.
        if failureObserver.didFail {
            return nil
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
}

private extension TokenUsageDashboardSnapshot {
    static func comparisonTotal(
        usageStore: TokenUsageStore,
        selectedPeriod: TokenUsageDashboardPeriod,
        inputScope: TokenUsageInputScope,
        now: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>?,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> Int? {
        switch selectedPeriod {
        case .today:
            let todayStart = calendar.startOfDay(for: now)
            let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            return usageStore.comparisonTokenTotal(
                startingAt: yesterdayStart,
                endingBefore: todayStart,
                inputScope: inputScope,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        case .sevenDays:
            let sevenDaysAgo = periodStartDate(dayCount: 7, now: now, calendar: calendar)
            let fourteenDaysAgo = calendar.date(byAdding: .day, value: -7, to: sevenDaysAgo) ?? sevenDaysAgo
            return usageStore.comparisonTokenTotal(
                startingAt: fourteenDaysAgo,
                endingBefore: sevenDaysAgo,
                inputScope: inputScope,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        case .thirtyDays:
            let thirtyDaysAgo = periodStartDate(dayCount: 30, now: now, calendar: calendar)
            let sixtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: thirtyDaysAgo) ?? thirtyDaysAgo
            return usageStore.comparisonTokenTotal(
                startingAt: sixtyDaysAgo,
                endingBefore: thirtyDaysAgo,
                inputScope: inputScope,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
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
        inputScope: TokenUsageInputScope,
        language: TokenMeteringLanguage
    ) -> [TokenUsageDashboardProjectFilter] {
        let totalTokens = totals.values.reduce(0) { $0 + $1.totals.total(for: inputScope) }
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
                detail: formatTokens(value.totals.total(for: inputScope)),
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
