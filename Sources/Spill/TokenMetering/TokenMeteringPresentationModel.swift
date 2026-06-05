import Foundation

struct TokenMeteringModeStatus: Identifiable, Equatable {
    let id: String
    let title: String
    let state: String
    let detail: String
    let isActive: Bool
}

struct TokenUsageDashboardKPI: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let detail: String
}

struct TokenUsageDashboardBarRow: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let ratio: Double
}

struct TokenUsageDashboardSessionRow: Identifiable, Equatable {
    let id: String
    let runID: String
    let value: String
    let detail: String
}

struct TokenUsageDashboardToolFilter: Identifiable, Equatable {
    let tool: TokenUsageAITool?
    let title: String
    let detail: String
    let isSelected: Bool

    var id: String {
        tool?.rawValue ?? "all"
    }
}

enum TokenUsageDashboardPeriod: String, CaseIterable, Equatable {
    case today
    case sevenDays
    case thirtyDays
    case all

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .sevenDays:
            return "7 days"
        case .thirtyDays:
            return "30 days"
        case .all:
            return "All"
        }
    }
}

struct TokenUsageDashboardPeriodFilter: Identifiable, Equatable {
    let period: TokenUsageDashboardPeriod
    let title: String
    let detail: String
    let isSelected: Bool

    var id: String {
        period.rawValue
    }
}

struct TokenUsageSelfTestMessage: Equatable {
    let text: String
    let isSuccess: Bool
}

struct TokenUsageDashboardSnapshot: Equatable {
    let eventCount: Int
    let totalTokens: Int
    let kpis: [TokenUsageDashboardKPI]
    let periodFilters: [TokenUsageDashboardPeriodFilter]
    let toolFilters: [TokenUsageDashboardToolFilter]
    let toolRows: [TokenUsageDashboardBarRow]
    let taskRows: [TokenUsageDashboardBarRow]
    let stageRows: [TokenUsageDashboardBarRow]
    let sourceRows: [TokenUsageDashboardBarRow]
    let sessions: [TokenUsageDashboardSessionRow]

    init(
        events: [TokenUsageEvent],
        selectedTool: TokenUsageAITool? = nil,
        selectedPeriod: TokenUsageDashboardPeriod = .all,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let periodEvents = Self.filterEvents(
            events,
            selectedPeriod: selectedPeriod,
            now: now,
            calendar: calendar
        )
        let visibleEvents = selectedTool.map { tool in
            periodEvents.filter { $0.aiTool == tool }
        } ?? periodEvents
        eventCount = visibleEvents.count
        totalTokens = visibleEvents.reduce(0) { $0 + $1.totalTokens }

        let allPeriodTotals = Self.periodTotals(events: events, now: now, calendar: calendar)
        periodFilters = TokenUsageDashboardPeriod.allCases.map { period in
            TokenUsageDashboardPeriodFilter(
                period: period,
                title: period.title,
                detail: Self.formatTokens(allPeriodTotals[period, default: 0]),
                isSelected: selectedPeriod == period
            )
        }

        let allToolTotals = Self.toolTotals(events: periodEvents)
        toolFilters = Self.toolFilters(
            selectedTool: selectedTool,
            totals: allToolTotals,
            totalEvents: periodEvents.count
        )

        let inputTokens = visibleEvents.reduce(0) { $0 + $1.inputTokens }
        let outputTokens = visibleEvents.reduce(0) { $0 + $1.outputTokens }
        let averageLatency = visibleEvents.isEmpty
            ? 0
            : visibleEvents.reduce(0) { $0 + $1.latencyMS } / visibleEvents.count

        kpis = [
            TokenUsageDashboardKPI(
                id: "total",
                title: "Total Tokens",
                value: Self.formatTokens(totalTokens),
                detail: "\(visibleEvents.count) local events"
            ),
            TokenUsageDashboardKPI(
                id: "input",
                title: "Input",
                value: Self.formatTokens(inputTokens),
                detail: Self.percentageDetail(value: inputTokens, total: totalTokens)
            ),
            TokenUsageDashboardKPI(
                id: "output",
                title: "Output",
                value: Self.formatTokens(outputTokens),
                detail: Self.percentageDetail(value: outputTokens, total: totalTokens)
            ),
            TokenUsageDashboardKPI(
                id: "latency",
                title: "Avg Latency",
                value: "\(averageLatency) ms",
                detail: "per local span"
            )
        ]

        toolRows = Self.rows(
            values: Self.toolTotals(events: visibleEvents),
            total: totalTokens,
            id: { $0.rawValue },
            label: { $0.dashboardLabel }
        )

        taskRows = Self.rows(
            values: Dictionary(grouping: visibleEvents, by: \.taskType)
                .mapValues { groupedEvents in
                    groupedEvents.reduce(0) { $0 + $1.totalTokens }
                },
            total: totalTokens,
            id: { $0.rawValue },
            label: { $0.dashboardLabel }
        )

        stageRows = Self.rows(
            values: Dictionary(grouping: visibleEvents, by: \.stage)
                .mapValues { groupedEvents in
                    groupedEvents.reduce(0) { $0 + $1.totalTokens }
                },
            total: totalTokens,
            id: { $0.rawValue },
            label: { $0.dashboardLabel }
        )

        sourceRows = Self.rows(
            values: Self.sourceTotals(events: visibleEvents),
            total: totalTokens,
            id: { $0.rawValue },
            label: { $0.label }
        )

        sessions = Self.sessionRows(events: visibleEvents)
    }

    private init(events: [TokenUsageEvent], selectedTool legacySelectedTool: TokenUsageAITool?) {
        self.init(events: events, selectedTool: legacySelectedTool, selectedPeriod: .all)
    }

    static let empty = TokenUsageDashboardSnapshot(events: [])

    static func formatTokens(_ value: Int) -> String {
        NumberFormatter.tokenUsage.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func filterEvents(
        _ events: [TokenUsageEvent],
        selectedPeriod: TokenUsageDashboardPeriod,
        now: Date,
        calendar: Calendar
    ) -> [TokenUsageEvent] {
        guard let cutoff = cutoffDate(for: selectedPeriod, now: now, calendar: calendar) else {
            return events
        }

        return events.filter { event in
            guard let createdAt = ISO8601DateFormatter.tokenUsage.date(from: event.createdAt) else {
                return false
            }
            return createdAt >= cutoff && createdAt <= now
        }
    }

    private static func periodTotals(
        events: [TokenUsageEvent],
        now: Date,
        calendar: Calendar
    ) -> [TokenUsageDashboardPeriod: Int] {
        Dictionary(uniqueKeysWithValues: TokenUsageDashboardPeriod.allCases.map { period in
            let total = filterEvents(
                events,
                selectedPeriod: period,
                now: now,
                calendar: calendar
            ).reduce(0) { $0 + $1.totalTokens }
            return (period, total)
        })
    }

    private static func cutoffDate(
        for period: TokenUsageDashboardPeriod,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        switch period {
        case .today:
            return calendar.startOfDay(for: now)
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .all:
            return nil
        }
    }

    private static func visibleEvents(events: [TokenUsageEvent], selectedTool: TokenUsageAITool?) -> [TokenUsageEvent] {
        selectedTool.map { tool in
            events.filter { $0.aiTool == tool }
        } ?? events
    }

    private static func rows<Key: Hashable>(
        values: [Key: Int],
        total: Int,
        id: (Key) -> String,
        label: (Key) -> String
    ) -> [TokenUsageDashboardBarRow] {
        values
            .filter { $0.value > 0 }
            .sorted {
                if $0.value == $1.value {
                    return label($0.key) < label($1.key)
                }
                return $0.value > $1.value
            }
            .map { key, value in
                TokenUsageDashboardBarRow(
                    id: id(key),
                    title: label(key),
                    value: Self.formatTokens(value),
                    ratio: total > 0 ? Double(value) / Double(total) : 0
                )
            }
    }

    private static func toolTotals(events: [TokenUsageEvent]) -> [TokenUsageAITool: Int] {
        Dictionary(grouping: events, by: \.aiTool)
            .mapValues { groupedEvents in
                groupedEvents.reduce(0) { $0 + $1.totalTokens }
            }
    }

    private static func toolFilters(
        selectedTool: TokenUsageAITool?,
        totals: [TokenUsageAITool: Int],
        totalEvents: Int
    ) -> [TokenUsageDashboardToolFilter] {
        let allTotal = totals.values.reduce(0, +)
        let allFilter = TokenUsageDashboardToolFilter(
            tool: nil,
            title: "All",
            detail: "\(totalEvents) events / \(formatTokens(allTotal)) tokens",
            isSelected: selectedTool == nil
        )
        let toolFilters = TokenUsageAITool.allCases.map { tool in
            TokenUsageDashboardToolFilter(
                tool: tool,
                title: tool.dashboardLabel,
                detail: formatTokens(totals[tool, default: 0]),
                isSelected: selectedTool == tool
            )
        }

        return [allFilter] + toolFilters
    }

    private static func sourceTotals(events: [TokenUsageEvent]) -> [TokenUsageSource: Int] {
        events.reduce(into: [:]) { result, event in
            result[.system, default: 0] += event.tokenBreakdown.system
            result[.user, default: 0] += event.tokenBreakdown.user
            result[.history, default: 0] += event.tokenBreakdown.history
            result[.repoContext, default: 0] += event.tokenBreakdown.repoContext
            result[.toolOutput, default: 0] += event.tokenBreakdown.toolOutput
            result[.generatedOutput, default: 0] += event.tokenBreakdown.generatedOutput
            result[.unknown, default: 0] += event.tokenBreakdown.unknown
        }
    }

    private static func sessionRows(events: [TokenUsageEvent]) -> [TokenUsageDashboardSessionRow] {
        Dictionary(grouping: events, by: \.runID)
            .map { runID, groupedEvents in
                let total = groupedEvents.reduce(0) { $0 + $1.totalTokens }
                let latency = groupedEvents.reduce(0) { $0 + $1.latencyMS }
                let latest = groupedEvents.map(\.createdAt).max() ?? "unknown"
                return TokenUsageDashboardSessionRow(
                    id: runID,
                    runID: runID,
                    value: Self.formatTokens(total),
                    detail: "\(groupedEvents.count) spans / \(latency) ms / \(latest)"
                )
            }
            .sorted { $0.detail > $1.detail }
    }

    private static func percentageDetail(value: Int, total: Int) -> String {
        guard total > 0 else {
            return "0% of total"
        }

        let percent = Int((Double(value) / Double(total) * 100).rounded())
        return "\(percent)% of total"
    }
}

enum TokenMeteringPreferencesModel {
    static let modes: [TokenMeteringModeStatus] = [
        TokenMeteringModeStatus(
            id: "local_only",
            title: "Local only",
            state: "Active without login",
            detail: "Detailed token counts and safe categories stay in this app on this computer.",
            isActive: true
        ),
        TokenMeteringModeStatus(
            id: "cloud_aggregate",
            title: "Cloud aggregate",
            state: "Requires login and explicit enablement",
            detail: "Future sync can send totals, timestamps, model ids, latency, and opaque ids only.",
            isActive: false
        ),
        TokenMeteringModeStatus(
            id: "cloud_detailed",
            title: "Cloud detailed",
            state: "Separate token-only opt-in",
            detail: "Future drill-down can add task/source enum labels and numeric breakdowns, never content.",
            isActive: false
        )
    ]

    static let forbiddenContentLabels = [
        "prompts",
        "commands",
        "responses",
        "file paths",
        "repo names",
        "diffs",
        "logs",
        "source content",
        "environment values",
        "secrets"
    ]
}

private enum TokenUsageSource: Hashable {
    case system
    case user
    case history
    case repoContext
    case toolOutput
    case generatedOutput
    case unknown

    var label: String {
        switch self {
        case .system:
            return "System"
        case .user:
            return "User"
        case .history:
            return "History"
        case .repoContext:
            return "Repo context"
        case .toolOutput:
            return "Tool output"
        case .generatedOutput:
            return "Generated output"
        case .unknown:
            return "Unclassified input"
        }
    }
}

extension TokenUsageSource {
    var rawValue: String {
        switch self {
        case .system:
            return "system"
        case .user:
            return "user"
        case .history:
            return "history"
        case .repoContext:
            return "repo_context"
        case .toolOutput:
            return "tool_output"
        case .generatedOutput:
            return "generated_output"
        case .unknown:
            return "unknown"
        }
    }
}

extension TokenUsageAITool {
    var dashboardLabel: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .codex:
            return "Codex"
        case .claude:
            return "Claude"
        case .antigravity:
            return "Antigravity"
        case .openAI:
            return "OpenAI"
        }
    }
}

private extension TokenUsageTaskType {
    var dashboardLabel: String {
        [
            "uncategorized": "Uncategorized",
            "analysis": "Analysis",
            "prd_drafting": "PRD drafting",
            "architecture": "Architecture",
            "code_generation": "Code generation",
            "refactoring": "Refactoring",
            "code_review": "Code review",
            "test_generation": "Test generation",
            "testing": "Testing",
            "debugging": "Debugging",
            "documentation": "Documentation",
            "release_notes": "Release notes"
        ][rawValue] ?? rawValue.tokenUsageTitle
    }
}

private extension TokenUsageStage {
    var dashboardLabel: String {
        [
            "monitor": "Monitor",
            "classify": "Classify",
            "plan": "Plan",
            "draft": "Draft",
            "revise": "Revise",
            "implement": "Implement",
            "verify": "Verify",
            "summarize": "Summarize"
        ][rawValue] ?? rawValue.tokenUsageTitle
    }
}

private extension String {
    var tokenUsageTitle: String {
        split(separator: "_")
            .map { part in
                guard let first = part.first else {
                    return ""
                }
                return first.uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }
}

private extension NumberFormatter {
    static let tokenUsage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
