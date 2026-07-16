import Foundation

struct TokenUsageDashboardBuildRequest {
    let selectedTool: TokenUsageAITool?
    let selectedPeriod: TokenUsageDashboardPeriod
    let selectedCalendarDayID: String?
    let selectedProjectID: String?
    let selectedSessionID: String?
    let language: TokenMeteringLanguage
    let localAliases: [String: String]
    let showAdvancedTools: Bool
    let visibleAITools: Set<TokenUsageAITool>?
    let now: Date
    let proposedCalendarMonthStart: Date?
    let calendar: Calendar
    let periodOffset: Int
    let inputScope: TokenUsageInputScope
    let availableDateBounds: TokenUsageDashboardDateBounds
}

extension TokenUsageDashboardBuildRequest {
    func replacingAvailableDateBounds(
        _ bounds: TokenUsageDashboardDateBounds
    ) -> TokenUsageDashboardBuildRequest {
        TokenUsageDashboardBuildRequest(
            selectedTool: selectedTool,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID,
            selectedProjectID: selectedProjectID,
            selectedSessionID: selectedSessionID,
            language: language,
            localAliases: localAliases,
            showAdvancedTools: showAdvancedTools,
            visibleAITools: visibleAITools,
            now: now,
            proposedCalendarMonthStart: proposedCalendarMonthStart,
            calendar: calendar,
            periodOffset: periodOffset,
            inputScope: inputScope,
            availableDateBounds: bounds
        )
    }
}
