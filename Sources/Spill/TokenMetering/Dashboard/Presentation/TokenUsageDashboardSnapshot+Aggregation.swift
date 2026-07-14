import Foundation

extension TokenUsageDashboardSnapshot {
    struct LastUpdatedDates {
        var codex: Date?
        var claude: Date?
        var antigravity: Date?
        var overall: Date?
    }

    static func lastUpdatedDates(in events: [TokenUsageDashboardParsedEvent]) -> LastUpdatedDates {
        var dates = LastUpdatedDates()

        for event in events {
            guard let createdAt = event.createdAt else {
                continue
            }

            dates.overall = laterDate(dates.overall, createdAt)
            switch event.event.aiTool {
            case .codex:
                dates.codex = laterDate(dates.codex, createdAt)
            case .claude:
                dates.claude = laterDate(dates.claude, createdAt)
            case .antigravity:
                dates.antigravity = laterDate(dates.antigravity, createdAt)
            default:
                break
            }
        }

        return dates
    }

    private static func laterDate(_ current: Date?, _ candidate: Date) -> Date {
        guard let current else {
            return candidate
        }

        return max(current, candidate)
    }

    static func visibleEvents(events: [TokenUsageEvent], selectedTool: TokenUsageAITool?) -> [TokenUsageEvent] {
        selectedTool.map { tool in
            events.filter { $0.aiTool == tool }
        } ?? events
    }

    static func tokenTotals<Key: Hashable>(
        events: [TokenUsageDashboardParsedEvent],
        inputScope: TokenUsageInputScope = .includeCache,
        by key: (TokenUsageDashboardParsedEvent) -> Key
    ) -> [Key: Int] {
        var totals: [Key: Int] = [:]
        for event in events {
            totals[key(event), default: 0] += usageTokens(for: event.event, inputScope: inputScope)
        }
        return totals
    }

    static func toolTotals(
        events: [TokenUsageDashboardParsedEvent],
        inputScope: TokenUsageInputScope = .includeCache
    ) -> [TokenUsageAITool: Int] {
        tokenTotals(events: events, inputScope: inputScope) { $0.event.aiTool }
    }

    static func usageTokens(
        for event: TokenUsageEvent,
        inputScope: TokenUsageInputScope
    ) -> Int {
        switch inputScope {
        case .includeCache:
            event.totalTokens
        case .freshOnly:
            max(0, event.outputTokens)
                + max(0, event.tokenAccounting?.uncachedInputTokens ?? 0)
        }
    }

    static func workflowUsage(
        events: [TokenUsageDashboardParsedEvent],
        totalTokens: Int,
        language: TokenMeteringLanguage
    ) -> TokenUsageDashboardWorkflowUsage {
        guard !events.isEmpty else {
            return TokenUsageDashboardWorkflowUsage(rows: [])
        }

        let assistedEvents = events.filter { event in
            TokenUsageWorkflowAssistance.isAssisted(event.event)
        }
        let assistedTokens = assistedEvents.reduce(0) { $0 + $1.event.totalTokens }
        let workRatio = chartRatio(tokens: assistedEvents.count, totalTokens: events.count)
        let tokenRatio = chartRatio(tokens: assistedTokens, totalTokens: totalTokens)

        return TokenUsageDashboardWorkflowUsage(rows: [
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

    static func toolFilters(
        selectedTool: TokenUsageAITool?,
        totals: [TokenUsageAITool: Int],
        totalEvents: Int,
        showAdvancedTools: Bool,
        visibleTools: Set<TokenUsageAITool>?,
        language: TokenMeteringLanguage
    ) -> [TokenUsageDashboardToolFilter] {
        let allTotal = totals.values.reduce(0, +)
        let allFilterDetail = TokenMeteringL10n.eventsTokensDetail(
            eventCount: totalEvents,
            tokens: formatTokens(allTotal),
            language: language
        )
        let allFilter = TokenUsageDashboardToolFilter(
            tool: nil,
            title: TokenMeteringL10n.text(.allTools, language: language),
            detail: allFilterDetail,
            shareLabel: nil,
            isSelected: selectedTool == nil
        )
        let toolsToShow: [TokenUsageAITool] = showAdvancedTools
            ? TokenUsageAITool.allCases
            : TokenUsageAITool.dashboardTools
        let visibleToolsToShow = visibleTools.map { allowedTools in
            toolsToShow.filter { allowedTools.contains($0) }
        } ?? toolsToShow
        let toolFilters = visibleToolsToShow.map { tool in
            let tokens = totals[tool, default: 0]
            let ratio = TokenUsageDashboardSnapshot.chartRatio(
                tokens: tokens,
                totalTokens: allTotal
            )
            return TokenUsageDashboardToolFilter(
                tool: tool,
                title: tool.dashboardLabel(language: language),
                detail: formatTokens(tokens),
                shareLabel: formatPercentage(ratio * 100.0),
                isSelected: selectedTool == tool
            )
        }

        return [allFilter] + toolFilters
    }

    static func projectFilters(
        events: [TokenUsageDashboardParsedEvent],
        selectedProjectID: String?,
        inputScope: TokenUsageInputScope = .includeCache,
        language: TokenMeteringLanguage
    ) -> [TokenUsageDashboardProjectFilter] {
        let totalTokens = events.reduce(0) {
            $0 + usageTokens(for: $1.event, inputScope: inputScope)
        }
        let allFilter = TokenUsageDashboardProjectFilter(
            projectID: nil,
            title: TokenMeteringL10n.text(.allFolders, language: language),
            detail: TokenMeteringL10n.eventsTokensDetail(
                eventCount: events.count,
                tokens: formatTokens(totalTokens),
                language: language
            ),
            isSelected: selectedProjectID == nil
        )
        let projectRows = Dictionary(grouping: events) { $0.event.projectID }
            .map { projectID, groupedEvents in
                let tokens = groupedEvents.reduce(0) {
                    $0 + usageTokens(for: $1.event, inputScope: inputScope)
                }
                return TokenUsageDashboardProjectFilter(
                    projectID: projectID,
                    title: projectTitle(projectID, language: language),
                    detail: formatTokens(tokens),
                    isSelected: selectedProjectID == projectID
                )
            }
            .sorted { lhs, rhs in
                projectFilterPrecedes(lhs, rhs)
            }

        return [allFilter] + projectRows
    }

    private static func projectFilterPrecedes(
        _ lhs: TokenUsageDashboardProjectFilter,
        _ rhs: TokenUsageDashboardProjectFilter
    ) -> Bool {
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

    static func sourceTotals(events: [TokenUsageDashboardParsedEvent]) -> [TokenUsageSource: Int] {
        var totals: [TokenUsageSource: Int] = [:]
        for parsedEvent in events {
            let event = parsedEvent.event
            totals[.system, default: 0] += event.tokenBreakdown.system
            totals[.user, default: 0] += event.tokenBreakdown.user
            totals[.history, default: 0] += event.tokenBreakdown.history
            totals[.repoContext, default: 0] += event.tokenBreakdown.repoContext
            totals[.toolOutput, default: 0] += event.tokenBreakdown.toolOutput
            totals[.generatedOutput, default: 0] += event.tokenBreakdown.generatedOutput
            totals[.unknown, default: 0] += event.tokenBreakdown.unknown
        }
        return totals
    }

    static func inputAccounting(
        events: [TokenUsageDashboardParsedEvent],
        inputTokens: Int,
        language: TokenMeteringLanguage
    ) -> TokenUsageDashboardInputAccounting {
        var totals: [TokenUsageInputAccountingCategory: Int] = [:]
        for parsedEvent in events {
            let event = parsedEvent.event
            guard event.inputTokens > 0 else {
                continue
            }

            guard let accounting = event.tokenAccounting else {
                totals[.unclassifiedInput, default: 0] += event.inputTokens
                continue
            }

            totals[.uncachedInput, default: 0] += accounting.uncachedInputTokens
            totals[.cacheCreationInput, default: 0] += accounting.cacheCreationInputTokens
            totals[.cacheReadInput, default: 0] += accounting.cacheReadInputTokens
            let unclassifiedInput = max(0, event.inputTokens - accounting.measuredInputTokens)
            totals[.unclassifiedInput, default: 0] += unclassifiedInput
        }

        let rows = TokenUsageDashboardRowBuilder.rows(
            candidates: TokenUsageInputAccountingCategory.allCases,
            totalTokens: inputTokens,
            tokens: { totals[$0, default: 0] },
            id: { $0.rawValue },
            label: { $0.label(language: language) }
        )
        return TokenUsageDashboardInputAccounting(
            rows: rows,
            rawInputTokens: inputTokens,
            exactFreshInputTokens: totals[.uncachedInput, default: 0]
        )
    }

    static func sessionRows(
        events: [TokenUsageDashboardParsedEvent],
        language: TokenMeteringLanguage,
        localAliases: [String: String],
        calendar: Calendar,
        now: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> [TokenUsageDashboardSessionRow] {
        Dictionary(grouping: events) { event in
            workItemKey(for: event)
        }
            .map { key, groupedEvents in
                let totalT = groupedEvents.reduce(0) { $0 + $1.event.totalTokens }
                let latency = groupedEvents.reduce(0) { $0 + $1.event.latencyMS }
                let latestDate = groupedEvents
                    .compactMap(\.createdAt)
                    .max()
                let latestRaw = latestDate.map { ISO8601DateFormatter.tokenUsage.string(from: $0) }
                    ?? groupedEvents.map(\.event.createdAt).max()
                    ?? "unknown"
                let latestDisplay = latestDate.map {
                    Self.formatLocalTimestamp($0, now: now, calendar: calendar, locale: locale, timeZone: timeZone)
                } ?? latestRaw
                let runIDs = Set(groupedEvents.map(\.event.runID))

                return (
                    row: TokenUsageDashboardSessionRow(
                        id: key.id,
                        runID: key.id,
                        projectID: key.projectID,
                        projectTitle: Self.projectTitle(key.projectID, language: language),
                        title: localAliases[key.id] ?? Self.workItemTitle(key: key, language: language),
                        value: Self.formatTokens(totalT),
                        detail: TokenMeteringL10n.spansDetail(
                            spanCount: groupedEvents.count,
                            latencyMS: latency > 0 ? latency : nil,
                            latest: latestDisplay,
                            language: language
                        ),
                        eventCount: groupedEvents.count
                    ),
                    latest: latestRaw,
                    totalTokens: totalT,
                    spanCount: groupedEvents.count,
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

    private static func workItemKey(
        for event: TokenUsageEvent,
        calendar: Calendar
    ) -> TokenUsageDashboardWorkItemKey {
        TokenUsageDashboardWorkItemKey(
            projectID: event.projectID,
            taskType: event.taskType,
            stage: event.stage,
            dayBucket: localDayBucket(for: event.createdAt, calendar: calendar)
        )
    }

    static func workItemID(
        for event: TokenUsageEvent,
        calendar: Calendar
    ) -> String {
        workItemKey(for: event, calendar: calendar).id
    }

    private static func workItemKey(
        for event: TokenUsageDashboardParsedEvent
    ) -> TokenUsageDashboardWorkItemKey {
        TokenUsageDashboardWorkItemKey(
            projectID: event.event.projectID,
            taskType: event.event.taskType,
            stage: event.event.stage,
            dayBucket: event.dayBucket
        )
    }

    static func workItemID(
        for event: TokenUsageDashboardParsedEvent
    ) -> String {
        workItemKey(for: event).id
    }
}
