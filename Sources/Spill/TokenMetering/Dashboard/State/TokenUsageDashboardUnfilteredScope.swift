import Foundation

/// Identifies what the published unfiltered snapshot was built from. That snapshot
/// never depends on the selected tool, so switching only the tool chip can reuse it
/// instead of aggregating the whole range a second time.
struct TokenUsageDashboardUnfilteredScope {
    /// Reuse stays within this window so the live-update comparison never sees a
    /// snapshot much older than the one the dashboard just replaced.
    static let maximumReuseAge: TimeInterval = 60

    private struct Key: Equatable {
        let period: TokenUsageDashboardPeriod
        let calendarDayID: String?
        let language: TokenMeteringLanguage
        let localAliases: [String: String]
        let showAdvancedTools: Bool
        let visibleAITools: Set<TokenUsageAITool>?
        let proposedCalendarMonthStart: Date?
        let calendar: Calendar
        let periodOffset: Int
        let inputScope: TokenUsageInputScope
        let dataRevision: UInt64
    }

    private let key: Key
    private let builtAt: Date

    /// Nil for scopes the SQL snapshot path cannot answer, or when no data revision
    /// was captured, so those builds never become reusable.
    init?(request: TokenUsageDashboardBuildRequest, dataRevision: UInt64?) {
        guard let dataRevision, request.selectedProjectID == nil, request.selectedSessionID == nil else {
            return nil
        }
        key = Key(
            period: request.selectedPeriod,
            calendarDayID: request.selectedCalendarDayID,
            language: request.language,
            localAliases: request.localAliases,
            showAdvancedTools: request.showAdvancedTools,
            visibleAITools: request.visibleAITools,
            proposedCalendarMonthStart: request.proposedCalendarMonthStart,
            calendar: request.calendar,
            periodOffset: request.periodOffset,
            inputScope: request.inputScope,
            dataRevision: dataRevision
        )
        builtAt = request.now
    }

    func admitsReuse(for next: TokenUsageDashboardUnfilteredScope) -> Bool {
        let age = next.builtAt.timeIntervalSince(builtAt)
        return key == next.key && age >= 0 && age < Self.maximumReuseAge
    }
}
