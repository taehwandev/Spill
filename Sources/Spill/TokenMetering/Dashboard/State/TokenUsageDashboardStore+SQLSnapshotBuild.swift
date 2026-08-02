import Foundation

extension TokenUsageDashboardStore {
    /// No project/session/day drill-down: every dashboard output can be answered from SQL
    /// aggregate queries alone (see TokenUsageDashboardSnapshot+SQLFactory.swift), for either
    /// inputScope, so this skips loadEvents entirely rather than loading and holding the full
    /// raw row array just to recompute totals the store already has SQL paths for.
    nonisolated static func canBuildSnapshotFromSQL(for request: TokenUsageDashboardBuildRequest) -> Bool {
        request.selectedProjectID == nil
            && request.selectedSessionID == nil
            && request.selectedCalendarDayID == nil
    }

    /// Builds the full SQL-path refresh payload on ONE connection and ONE read transaction: the
    /// date bounds, the derived buildRequest, the period-filter chips, the panel summary, and both
    /// snapshot halves. Publishing all of these from a single DB commit point is the whole point --
    /// previously the three surrounding reads (dateBounds, period totals, panel summary) each ran on
    /// their own later connection, so a writer committing in between could make those fields
    /// disagree with the snapshot body, and the stored periodFilterTotals could diverge from the
    /// snapshot's own in-transaction period chips.
    ///
    /// `request` is the raw (bounds-less) request; buildRequest is derived here from the freshly read
    /// dateBounds so the availableDateBounds feeding calendar-month resolution matches everything else
    /// read in this transaction. `canBuildSnapshotFromSQL` inspects only project/session/day, none of
    /// which replacingAvailableDateBounds touches, so callers may gate on the raw request before the
    /// bounds are known.
    ///
    /// Query set is caller-controlled so each call site pays exactly the queries it consumed before:
    /// `loadsPeriodFilterTotals` controls whether the shared period map is returned to the caller;
    /// `cachedPeriodFilterTotals` mirrors refreshAsync's reuse semantics and avoids the query when a
    /// valid copy was handed in. Snapshot construction always needs that map for its period chips,
    /// so rebuild/calendar paths may load it inside the snapshot query set without publishing it.
    /// `loadsPanelSummary` mirrors `refreshesPanelSummary`.
    ///
    /// Returns nil (fail closed) on any open/statement failure. The shared period map and snapshot
    /// pair are built as one fail-closed unit, so a failure skips the surrounding panel-summary read;
    /// checking that result directly is more accurate than probing a separate connection first (a prior version used
    /// dashboardSummaryIfAvailable as a canary on its own independent connection, which said nothing
    /// about whether the build's connection would also open, so a canary-pass + build-fail could slip
    /// an empty snapshot through).
    nonisolated static func buildSnapshotOutputFromSQL(
        usageStore: TokenUsageStore,
        request: TokenUsageDashboardBuildRequest,
        loadsPeriodFilterTotals: Bool,
        cachedPeriodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals],
        loadsPanelSummary: Bool
    ) -> TokenUsageDashboardSQLBuildResult? {
        usageStore.withDatabaseConnection(nil, default: nil) { database -> TokenUsageDashboardSQLBuildResult? in
            let dateBounds = usageStore.dashboardDateBounds(
                selectedTool: request.selectedTool,
                dashboardToolsOnly: !request.showAdvancedTools,
                visibleTools: request.visibleAITools,
                database: database
            )
            let buildRequest = request.replacingAvailableDateBounds(dateBounds)

            guard let pairResult = buildSnapshotPairOutputFromSQL(
                usageStore: usageStore,
                request: buildRequest,
                cachedPeriodFilterTotals: cachedPeriodFilterTotals,
                database: database
            ) else {
                return nil
            }
            let output = pairResult.output

            // The pair already consumed the one shared period map. Publish that map only when the
            // caller requested refreshed filter totals; otherwise preserve the caller's cache contract.
            let periodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals]
            if loadsPeriodFilterTotals {
                periodFilterTotals = pairResult.periodFilterTotals
            } else {
                periodFilterTotals = cachedPeriodFilterTotals
            }

            let panelSummary = loadsPanelSummary
                ? panelSummarySnapshotFromSQL(from: usageStore, for: buildRequest, database: database)
                : nil

            return TokenUsageDashboardSQLBuildResult(
                output: output,
                dateBounds: dateBounds,
                periodFilterTotals: periodFilterTotals,
                panelSummary: panelSummary
            )
        }
    }

    /// The two buildFromSQLAggregates passes (filtered + selectedTool==nil unfiltered) plus the
    /// shared calendar-month resolution, all threaded onto the caller's `database` so both halves
    /// read the exact same WAL snapshot; if each opened its own connection a writer committing
    /// between the passes could give them inconsistent totals for the same instant. Returns nil on
    /// any statement failure so buildSnapshotOutputFromSQL can fail closed.
    nonisolated private static func buildSnapshotPairOutputFromSQL(
        usageStore: TokenUsageStore,
        request: TokenUsageDashboardBuildRequest,
        cachedPeriodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals],
        database: OpaquePointer
    ) -> (
        output: TokenUsageDashboardSnapshotBuildOutput,
        periodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals]
    )? {
        let periodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals]
        if cachedPeriodFilterTotals.isEmpty {
            let failureObserver = TokenUsageQueryFailureObserver()
            periodFilterTotals = usageStore.allPeriodInputScopeTotals(
                now: request.now,
                calendar: request.calendar,
                dashboardToolsOnly: !request.showAdvancedTools,
                visibleTools: request.visibleAITools,
                database: database,
                failureObserver: failureObserver
            )
            guard !failureObserver.didFail else {
                return nil
            }
        } else {
            periodFilterTotals = cachedPeriodFilterTotals
        }

        guard let filtered = TokenUsageDashboardSnapshot.buildFromSQLAggregates(
            usageStore: usageStore,
            selectedTool: request.selectedTool,
            selectedPeriod: request.selectedPeriod,
            inputScope: request.inputScope,
            language: request.language,
            localAliases: request.localAliases,
            showAdvancedTools: request.showAdvancedTools,
            visibleTools: request.visibleAITools,
            now: request.now,
            calendarMonthStart: request.proposedCalendarMonthStart,
            periodOffset: request.periodOffset,
            calendar: request.calendar,
            preloadedPeriodFilterTotals: periodFilterTotals,
            database: database
        ) else {
            return nil
        }
        let unfiltered: TokenUsageDashboardSnapshot
        if request.selectedTool == nil {
            unfiltered = filtered
        } else {
            guard let computedUnfiltered = TokenUsageDashboardSnapshot.buildFromSQLAggregates(
                usageStore: usageStore,
                selectedTool: nil,
                selectedPeriod: request.selectedPeriod,
                inputScope: request.inputScope,
                language: request.language,
                localAliases: request.localAliases,
                showAdvancedTools: request.showAdvancedTools,
                visibleTools: request.visibleAITools,
                now: request.now,
                calendarMonthStart: request.proposedCalendarMonthStart,
                periodOffset: request.periodOffset,
                calendar: request.calendar,
                preloadedPeriodFilterTotals: periodFilterTotals,
                database: database
            ) else {
                return nil
            }
            unfiltered = computedUnfiltered
        }
        // calendarMonth resolution depends only on availableDateBounds/now/proposedMonthStart
        // (never on selectedTool), so it is identical for the filtered and unfiltered snapshots
        // above, matching buildPair's single shared displayCalendarMonth.
        let calendarMonth = TokenUsageDashboardSnapshot.normalizedCalendarMonthStart(
            availableDateBounds: request.availableDateBounds,
            now: request.now,
            proposedMonthStart: request.proposedCalendarMonthStart,
            calendar: request.calendar
        )
        let context = TokenUsageDashboardSnapshotBuildContext(
            events: [],
            showAdvancedTools: request.showAdvancedTools,
            calendar: request.calendar
        )
        return (
            output: TokenUsageDashboardSnapshotBuildOutput(
                snapshotPair: TokenUsageDashboardSnapshotPair(
                    filtered: filtered,
                    unfiltered: unfiltered,
                    calendarMonthStart: calendarMonth
                ),
                context: context,
                contextKey: TokenUsageDashboardContextCacheKey(events: [], request: request)
            ),
            periodFilterTotals: periodFilterTotals
        )
    }

    /// Panel summary read on the caller's shared connection. Mirrors loadPanelSummaryIfAvailable but
    /// preserves (returns nil), never substitutes .empty, when the summary is unavailable, so a
    /// transient statement failure leaves the previously published panel summary in place rather than
    /// blanking it -- matching the fail-closed contract of the surrounding SQL build.
    nonisolated private static func panelSummarySnapshotFromSQL(
        from usageStore: TokenUsageStore,
        for request: TokenUsageDashboardBuildRequest,
        database: OpaquePointer
    ) -> TokenUsagePanelSummarySnapshot? {
        let dayStart = request.calendar.startOfDay(for: request.now)
        let dayEnd = request.calendar.date(byAdding: .day, value: 1, to: dayStart) ?? request.now
        guard let summary = usageStore.dashboardSummaryIfAvailable(
            startingAt: dayStart,
            endingBefore: dayEnd,
            dashboardToolsOnly: !request.showAdvancedTools,
            visibleTools: request.visibleAITools,
            database: database
        ) else {
            return nil
        }
        return TokenUsagePanelSummarySnapshot(
            summary: summary,
            language: request.language
        )
    }
}
