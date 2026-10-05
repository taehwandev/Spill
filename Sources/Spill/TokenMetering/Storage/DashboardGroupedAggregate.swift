import Foundation

/// Exact roll-ups of the grouped dashboard scan; each one reproduces the statement it replaced,
/// including how that statement treated NULL and blank grouping values.
struct DashboardGroupedAggregate: Equatable {
    static let sourceKeys = [
        "system", "user", "history", "repo_context", "tool_output", "generated_output", "unknown"
    ]

    let rows: [DashboardGroupedAggregateRow]

    func focusedTotals() -> TokenUsageStore.DashboardFocusedTotals {
        var eventCount = 0, totalTokens = 0, freshTokens = 0, inputTokens = 0, outputTokens = 0
        var assistedEventCount = 0, assistedTotalTokens = 0
        for row in rows {
            eventCount += row.eventCount
            totalTokens += row.totalTokens
            freshTokens += row.freshTokens
            inputTokens += row.inputTokens
            outputTokens += row.outputTokens
            if row.isAssisted {
                assistedEventCount += row.eventCount
                assistedTotalTokens += row.totalTokens
            }
        }
        return TokenUsageStore.DashboardFocusedTotals(
            eventCount: eventCount, totalTokens: totalTokens, exactFreshTotalTokens: freshTokens,
            inputTokens: inputTokens, outputTokens: outputTokens,
            assistedEventCount: assistedEventCount, assistedTotalTokens: assistedTotalTokens
        )
    }

    /// Per-tool totals; a row stored without any tool label is not a dashboard tool row.
    func toolTotals() -> [TokenUsageAITool: TokenUsageInputScopeTotals] {
        rows.reduce(into: [:]) { totals, row in
            guard !row.toolLabel.isEmpty else { return }
            totals[row.tool] = Self.adding(totals[row.tool], row.inputScopeTotals)
        }
    }

    func projectTotals() -> [String: (eventCount: Int, totals: TokenUsageInputScopeTotals)] {
        rows.reduce(into: [:]) { totals, row in
            guard let key = row.projectID, !key.isEmpty else { return }
            let existing = totals[key]
            totals[key] = (
                eventCount: (existing?.eventCount ?? 0) + row.eventCount,
                totals: Self.adding(existing?.totals, row.inputScopeTotals)
            )
        }
    }

    func modelTotals() -> [String: TokenUsageInputScopeTotals] {
        rows.reduce(into: [:]) { totals, row in
            guard let key = row.modelKey, !key.isEmpty else { return }
            totals[key] = Self.adding(totals[key], row.inputScopeTotals)
        }
    }

    /// task_type or stage totals split by tool.
    func totalsByTool(
        key: KeyPath<DashboardGroupedAggregateRow, String?>
    ) -> [String: [TokenUsageAITool: TokenUsageInputScopeTotals]] {
        rows.reduce(into: [:]) { totals, row in
            guard let name = row[keyPath: key], !name.isEmpty else { return }
            totals[name, default: [:]][row.tool] = Self.adding(totals[name]?[row.tool], row.inputScopeTotals)
        }
    }

    func sourceTotals() -> [String: Int] {
        rows.reduce(into: Dictionary(uniqueKeysWithValues: Self.sourceKeys.map { ($0, 0) })) { totals, row in
            for (key, value) in row.sources { totals[key, default: 0] += value }
        }
    }

    func inputAccountingByTool() -> [TokenUsageAITool: [String: Int]] {
        rows.reduce(into: [:]) { totals, row in
            guard row.inputEventCount > 0 else { return }
            let split = [
                "uncached_input": row.uncachedInput,
                "cache_creation_input": row.cacheCreationInput,
                "cache_read_input": row.cacheReadInput,
                "unclassified_input": row.unclassifiedInput
            ]
            totals[row.tool, default: [:]].merge(split, uniquingKeysWith: +)
        }
    }

    private static func adding(
        _ existing: TokenUsageInputScopeTotals?, _ addition: TokenUsageInputScopeTotals
    ) -> TokenUsageInputScopeTotals {
        let existing = existing ?? .zero
        return TokenUsageInputScopeTotals(
            includeCache: existing.includeCache + addition.includeCache,
            freshOnly: existing.freshOnly + addition.freshOnly
        )
    }
}
