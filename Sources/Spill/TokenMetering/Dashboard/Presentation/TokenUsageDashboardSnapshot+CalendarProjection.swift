import Foundation

extension TokenUsageDashboardSnapshot {
    /// Month navigation changes the heatmap, leaving the selected analytics scope intact.
    func replacingCalendarMonth(
        _ month: Date,
        dayTotals: [String: TokenUsageInputScopeTotals],
        request: TokenUsageDashboardBuildRequest,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> TokenUsageDashboardSnapshot {
        let calendar = request.calendar
        let currentMonth = Self.monthStart(for: request.now, calendar: calendar)
        let firstMonth = request.availableDateBounds.earliest
            .map { Self.monthStart(for: $0, calendar: calendar) } ?? currentMonth
        let todayID = Self.dayID(for: request.now, calendar: calendar)
        return TokenUsageDashboardSnapshot(
            eventCount: eventCount, totalTokens: totalTokens, kpis: kpis,
            periodFilters: periodFilters, toolFilters: toolFilters,
            projectFilters: projectFilters, selectedProjectID: selectedProjectID,
            toolRows: toolRows, modelRows: modelRows, workflowUsage: workflowUsage,
            inputAccounting: inputAccounting, taskRows: taskRows, stageRows: stageRows,
            sourceRows: sourceRows, sessions: sessions, selectedSession: selectedSession,
            trendBuckets: trendBuckets,
            calendarDays: Self.calendarDays(
                events: [], monthStart: month, selectedCalendarDayID: selectedCalendarDayID,
                todayCalendarDayID: todayID, calendar: calendar, locale: locale, timeZone: timeZone,
                dayTokenTotals: dayTotals.mapValues { $0.total(for: request.inputScope) },
                rawDayTokenTotals: dayTotals.mapValues(\.includeCache)
            ),
            calendarMonthTitle: Self.formatCalendarMonth(month, locale: locale, timeZone: timeZone),
            calendarWeekdayTitles: Self.weekdayTitles(locale: locale),
            selectedCalendarDayID: selectedCalendarDayID,
            selectedCalendarDayTitle: selectedCalendarDayTitle,
            todayCalendarDayID: todayID,
            todayCalendarDayTitle: Self.formatCalendarDayTitle(request.now, locale: locale, timeZone: timeZone),
            canNavigatePreviousCalendarMonth: calendar.compare(month, to: firstMonth, toGranularity: .month) == .orderedDescending,
            canNavigateNextCalendarMonth: calendar.compare(month, to: currentMonth, toGranularity: .month) == .orderedAscending,
            codexLastUpdated: codexLastUpdated, claudeLastUpdated: claudeLastUpdated,
            antigravityLastUpdated: antigravityLastUpdated, overallLastUpdated: overallLastUpdated,
            codexLastUpdatedString: codexLastUpdatedString, claudeLastUpdatedString: claudeLastUpdatedString,
            antigravityLastUpdatedString: antigravityLastUpdatedString, overallLastUpdatedString: overallLastUpdatedString,
            comparisonTotalTokens: comparisonTotalTokens,
            canNavigatePreviousPeriod: canNavigatePreviousPeriod, canNavigateNextPeriod: canNavigateNextPeriod
        )
    }
}
