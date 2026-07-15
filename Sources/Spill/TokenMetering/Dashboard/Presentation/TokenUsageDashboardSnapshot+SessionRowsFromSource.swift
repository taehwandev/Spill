import Foundation

extension TokenUsageDashboardSnapshot {
    /// Mirrors sessionRows(events:...) in TokenUsageDashboardSnapshot+Aggregation.swift exactly,
    /// but groups TokenUsageDashboardSessionSourceRow (a narrow SQL projection) instead of full
    /// TokenUsageDashboardParsedEvent/TokenUsageEvent values, so a caller that only needs the
    /// work-item/session list doesn't have to hold every event's full token breakdown, accounting,
    /// and identifier fields in memory. Any change to the grouping, sort, or formatting rules here
    /// must be mirrored in the other function (and vice versa) until one replaces the other.
    static func sessionRows(
        sourceRows: [TokenUsageDashboardSessionSourceRow],
        inputScope: TokenUsageInputScope,
        language: TokenMeteringLanguage,
        localAliases: [String: String],
        calendar: Calendar,
        now: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> [TokenUsageDashboardSessionRow] {
        Dictionary(grouping: sourceRows) { row in
            TokenUsageDashboardWorkItemKey(
                projectID: row.projectID,
                taskType: row.taskType,
                stage: row.stage,
                dayBucket: row.dayBucket
            )
        }
            .map { key, groupedRows in
                let totalT = groupedRows.reduce(0) {
                    $0 + (inputScope == .includeCache ? $1.totalTokens : $1.freshTokens)
                }
                let latency = groupedRows.reduce(0) { $0 + $1.latencyMS }
                let latestDate = groupedRows.compactMap(\.createdAt).max()
                let latestRaw = latestDate.map { ISO8601DateFormatter.tokenUsage.string(from: $0) }
                    ?? groupedRows.map(\.rawCreatedAt).max()
                    ?? "unknown"
                let latestDisplay = latestDate.map {
                    Self.formatLocalTimestamp($0, now: now, calendar: calendar, locale: locale, timeZone: timeZone)
                } ?? latestRaw
                let runIDs = Set(groupedRows.map(\.runID))

                return (
                    row: TokenUsageDashboardSessionRow(
                        id: key.id,
                        runID: key.id,
                        projectID: key.projectID,
                        projectTitle: Self.projectTitle(key.projectID, language: language),
                        title: localAliases[key.id] ?? Self.workItemTitle(key: key, language: language),
                        value: Self.formatTokens(totalT),
                        detail: TokenMeteringL10n.spansDetail(
                            spanCount: groupedRows.count,
                            latencyMS: latency > 0 ? latency : nil,
                            latest: latestDisplay,
                            language: language
                        ),
                        eventCount: groupedRows.count
                    ),
                    latest: latestRaw,
                    totalTokens: totalT,
                    spanCount: groupedRows.count,
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
}
