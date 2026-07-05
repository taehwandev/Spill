import Foundation

struct PrivateUsageSharedSummary: Codable, Equatable, Sendable {
    static let currentSummaryVersion = 1
    private static let maxToolTotals = 64
    private static let maxModelTotals = 128
    private static let maxTaskTypeTotals = 64
    private static let maxStageTotals = 64
    private static let maxWorkItems = 256
    private static let overflowKey = "other"

    let schemaVersion: Int
    let summaryVersion: Int
    let bucketKind: String
    let bucketKey: String
    let bucketStartAt: String
    let bucketEndAt: String
    let timezone: String
    let generatedAt: String
    let totals: PrivateUsageTokenTotals
    let sourceTotals: [String: Int]
    let toolTotals: [String: PrivateUsageTokenTotals]
    let modelTotals: [String: PrivateUsageTokenTotals]
    let taskTypeTotals: [String: PrivateUsageTokenTotals]
    let stageTotals: [String: PrivateUsageTokenTotals]
    let workflowUsageTotals: PrivateUsageWorkflowUsageTotals
    let workItems: [PrivateUsageWorkItemAggregate]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case summaryVersion = "summary_version"
        case bucketKind = "bucket_kind"
        case bucketKey = "bucket_key"
        case bucketStartAt = "bucket_start_at"
        case bucketEndAt = "bucket_end_at"
        case timezone
        case generatedAt = "generated_at"
        case totals
        case sourceTotals = "source_totals"
        case toolTotals = "tool_totals"
        case modelTotals = "model_totals"
        case taskTypeTotals = "task_type_totals"
        case stageTotals = "stage_totals"
        case workflowUsageTotals = "workflow_usage_totals"
        case workItems = "work_items"
    }

    init(aggregate: PrivateUsageDailyAggregate) {
        schemaVersion = aggregate.schemaVersion
        summaryVersion = Self.currentSummaryVersion
        bucketKind = aggregate.bucketKind
        bucketKey = aggregate.bucketKey
        bucketStartAt = aggregate.bucketStartAt
        bucketEndAt = aggregate.bucketEndAt
        timezone = aggregate.timezone
        generatedAt = aggregate.generatedAt
        totals = aggregate.totals
        sourceTotals = aggregate.sourceTotals
        toolTotals = Self.compactTokenTotalsMap(aggregate.toolTotals, limit: Self.maxToolTotals)
        modelTotals = Self.compactTokenTotalsMap(aggregate.modelTotals, limit: Self.maxModelTotals)
        taskTypeTotals = Self.compactTokenTotalsMap(aggregate.taskTypeTotals, limit: Self.maxTaskTypeTotals)
        stageTotals = Self.compactTokenTotalsMap(aggregate.stageTotals, limit: Self.maxStageTotals)
        workflowUsageTotals = aggregate.workflowUsageTotals
        workItems = Self.compactWorkItems(aggregate.workItems, limit: Self.maxWorkItems, bucketKey: aggregate.bucketKey)
    }

    func canonicalHash() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return PrivateUsageDailyBucketBuilder.sha256Hex(try encoder.encode(self))
    }
}

private extension PrivateUsageSharedSummary {
    static func compactTokenTotalsMap(
        _ totalsByKey: [String: PrivateUsageTokenTotals],
        limit: Int
    ) -> [String: PrivateUsageTokenTotals] {
        guard totalsByKey.count > limit else {
            return totalsByKey
        }
        guard limit > 0 else {
            return [:]
        }
        guard limit > 1 else {
            return [overflowKey: totalsByKey.values.reduce(.zero) { partial, totals in
                var merged = partial
                merged.add(totals)
                return merged
            }]
        }

        let sortedEntries: [(key: String, value: PrivateUsageTokenTotals)] = totalsByKey.sorted { lhs, rhs in
            if lhs.value.totalTokens != rhs.value.totalTokens {
                return lhs.value.totalTokens > rhs.value.totalTokens
            }
            if lhs.value.eventCount != rhs.value.eventCount {
                return lhs.value.eventCount > rhs.value.eventCount
            }
            return lhs.key < rhs.key
        }

        let keptEntries = sortedEntries.prefix(limit - 1).map { ($0.key, $0.value) }
        var compacted = Dictionary(uniqueKeysWithValues: keptEntries)
        var overflowTotals = compacted.removeValue(forKey: overflowKey) ?? .zero
        for entry in sortedEntries.dropFirst(limit - 1) {
            overflowTotals.add(entry.value)
        }
        if overflowTotals.eventCount > 0 || overflowTotals.totalTokens > 0 {
            compacted[overflowKey] = overflowTotals
        }
        return compacted
    }

    static func compactWorkItems(
        _ workItems: [PrivateUsageWorkItemAggregate],
        limit: Int,
        bucketKey: String
    ) -> [PrivateUsageWorkItemAggregate] {
        guard workItems.count > limit else {
            return workItems
        }
        guard limit > 0 else {
            return []
        }

        let sortedWorkItems = workItems.sorted(by: workItemSort)
        var keepCount = limit
        while true {
            let overflowTools = Set(sortedWorkItems.dropFirst(keepCount).map(\.aiTool))
            let nextKeepCount = max(0, limit - overflowTools.count)
            if nextKeepCount == keepCount {
                break
            }
            keepCount = nextKeepCount
        }

        let kept = Array(sortedWorkItems.prefix(keepCount))
        let overflowGroups = Dictionary(grouping: sortedWorkItems.dropFirst(keepCount), by: \.aiTool)
        let bucketIDPart = safeIDPart(bucketKey.split(separator: ":", maxSplits: 1).first.map(String.init) ?? bucketKey)
        let overflowItems = overflowGroups.keys.sorted().compactMap { aiTool -> PrivateUsageWorkItemAggregate? in
            guard let items = overflowGroups[aiTool], !items.isEmpty else {
                return nil
            }

            var totals = PrivateUsageTokenTotals.zero
            var firstEventAt = items[0].firstEventAt
            var lastEventAt = items[0].lastEventAt
            for item in items {
                totals.add(item.totals)
                if isTimestamp(item.firstEventAt, before: firstEventAt) {
                    firstEventAt = item.firstEventAt
                }
                if isTimestamp(lastEventAt, before: item.lastEventAt) {
                    lastEventAt = item.lastEventAt
                }
            }

            return PrivateUsageWorkItemAggregate(
                id: ["work", aiTool, overflowKey, bucketIDPart].map(safeIDPart).joined(separator: "__"),
                aiTool: aiTool,
                taskType: "uncategorized",
                stage: "summarize",
                model: overflowKey,
                totals: totals,
                firstEventAt: firstEventAt,
                lastEventAt: lastEventAt
            )
        }

        return (kept + overflowItems).sorted(by: workItemSort)
    }

    static func workItemSort(_ lhs: PrivateUsageWorkItemAggregate, _ rhs: PrivateUsageWorkItemAggregate) -> Bool {
        if lhs.totals.totalTokens != rhs.totals.totalTokens {
            return lhs.totals.totalTokens > rhs.totals.totalTokens
        }
        if lhs.totals.eventCount != rhs.totals.eventCount {
            return lhs.totals.eventCount > rhs.totals.eventCount
        }
        return lhs.id < rhs.id
    }

    static func safeIDPart(_ value: String) -> String {
        let normalized = value.lowercased()
        let scalars = normalized.unicodeScalars.map { scalar -> Character in
            if (48...57).contains(scalar.value) || (97...122).contains(scalar.value) {
                return Character(scalar)
            }
            return "_"
        }
        let collapsed = String(scalars)
            .split(separator: "_", omittingEmptySubsequences: true)
            .joined(separator: "_")
        return collapsed.isEmpty ? "unknown" : collapsed
    }

    static func isTimestamp(_ lhs: String, before rhs: String) -> Bool {
        guard let lhsDate = ISO8601DateFormatter.parseTokenUsageDate(from: lhs),
              let rhsDate = ISO8601DateFormatter.parseTokenUsageDate(from: rhs)
        else {
            return lhs < rhs
        }

        return lhsDate < rhsDate
    }
}
