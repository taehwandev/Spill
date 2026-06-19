import Foundation

struct TokenUsageDashboardSnapshotBuildContext {
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
