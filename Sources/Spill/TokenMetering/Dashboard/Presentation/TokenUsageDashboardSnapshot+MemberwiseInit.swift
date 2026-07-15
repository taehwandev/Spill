import Foundation

extension TokenUsageDashboardSnapshot {
    /// Explicit memberwise-style init for buildFromSQLAggregates. The struct's only other
    /// initializer (in TokenMeteringPresentationModel.swift) is private and assembles every
    /// field from a raw events array, so Swift does not synthesize a memberwise init here.
    init(
        eventCount: Int,
        totalTokens: Int,
        kpis: [TokenUsageDashboardKPI],
        periodFilters: [TokenUsageDashboardPeriodFilter],
        toolFilters: [TokenUsageDashboardToolFilter],
        projectFilters: [TokenUsageDashboardProjectFilter],
        selectedProjectID: String?,
        toolRows: [TokenUsageDashboardBarRow],
        modelRows: [TokenUsageDashboardBarRow],
        workflowUsage: TokenUsageDashboardWorkflowUsage,
        inputAccounting: TokenUsageDashboardInputAccounting,
        taskRows: [TokenUsageDashboardBarRow],
        stageRows: [TokenUsageDashboardBarRow],
        sourceRows: [TokenUsageDashboardBarRow],
        sessions: [TokenUsageDashboardSessionRow],
        selectedSession: TokenUsageDashboardSessionRow?,
        trendBuckets: [TokenUsageDashboardTrendBucket],
        calendarDays: [TokenUsageDashboardCalendarDay],
        calendarMonthTitle: String,
        calendarWeekdayTitles: [String],
        selectedCalendarDayID: String?,
        selectedCalendarDayTitle: String?,
        todayCalendarDayID: String,
        todayCalendarDayTitle: String,
        canNavigatePreviousCalendarMonth: Bool,
        canNavigateNextCalendarMonth: Bool,
        codexLastUpdated: Date?,
        claudeLastUpdated: Date?,
        antigravityLastUpdated: Date?,
        overallLastUpdated: Date?,
        codexLastUpdatedString: String?,
        claudeLastUpdatedString: String?,
        antigravityLastUpdatedString: String?,
        overallLastUpdatedString: String?,
        comparisonTotalTokens: Int?,
        canNavigatePreviousPeriod: Bool,
        canNavigateNextPeriod: Bool
    ) {
        self.eventCount = eventCount
        self.totalTokens = totalTokens
        self.kpis = kpis
        self.periodFilters = periodFilters
        self.toolFilters = toolFilters
        self.projectFilters = projectFilters
        self.selectedProjectID = selectedProjectID
        self.toolRows = toolRows
        self.modelRows = modelRows
        self.workflowUsage = workflowUsage
        self.inputAccounting = inputAccounting
        self.taskRows = taskRows
        self.stageRows = stageRows
        self.sourceRows = sourceRows
        self.sessions = sessions
        self.selectedSession = selectedSession
        self.trendBuckets = trendBuckets
        self.calendarDays = calendarDays
        self.calendarMonthTitle = calendarMonthTitle
        self.calendarWeekdayTitles = calendarWeekdayTitles
        self.selectedCalendarDayID = selectedCalendarDayID
        self.selectedCalendarDayTitle = selectedCalendarDayTitle
        self.todayCalendarDayID = todayCalendarDayID
        self.todayCalendarDayTitle = todayCalendarDayTitle
        self.canNavigatePreviousCalendarMonth = canNavigatePreviousCalendarMonth
        self.canNavigateNextCalendarMonth = canNavigateNextCalendarMonth
        self.codexLastUpdated = codexLastUpdated
        self.claudeLastUpdated = claudeLastUpdated
        self.antigravityLastUpdated = antigravityLastUpdated
        self.overallLastUpdated = overallLastUpdated
        self.codexLastUpdatedString = codexLastUpdatedString
        self.claudeLastUpdatedString = claudeLastUpdatedString
        self.antigravityLastUpdatedString = antigravityLastUpdatedString
        self.overallLastUpdatedString = overallLastUpdatedString
        self.comparisonTotalTokens = comparisonTotalTokens
        self.canNavigatePreviousPeriod = canNavigatePreviousPeriod
        self.canNavigateNextPeriod = canNavigateNextPeriod
    }
}
