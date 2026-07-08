import Foundation

extension PrivateUsageDailyBucketBuilder {
    static func deduplicateByContent(_ events: [TokenUsageEvent]) -> [TokenUsageEvent] {
        deduplicateExactContent(events).sorted(by: eventPrecedes)
    }

    static func deduplicateExactContent(_ events: [TokenUsageEvent]) -> [TokenUsageEvent] {
        struct ContentKey: Hashable {
            let aiTool: String
            let runID: String
            let createdAt: String
            let model: String
            let taskType: String
            let stage: String
            let inputTokens: Int
            let outputTokens: Int
        }
        var best = [ContentKey: TokenUsageEvent]()
        var noRunID = [TokenUsageEvent]()

        for event in events {
            guard !event.runID.isEmpty else {
                noRunID.append(event)
                continue
            }
            let key = ContentKey(
                aiTool: event.aiTool.rawValue,
                runID: event.runID,
                createdAt: event.createdAt,
                model: event.model,
                taskType: event.taskType.rawValue,
                stage: event.stage.rawValue,
                inputTokens: event.inputTokens,
                outputTokens: event.outputTokens
            )
            if let existing = best[key] {
                best[key] = preferredDuplicate(existing, event)
            } else {
                best[key] = event
            }
        }

        return Array(best.values) + noRunID
    }
}

extension PrivateUsageDailyBucketBuilder {
    // Removes Bug #2 duplicates for sync: same turn written 2-3x by Claude Code with
    // timestamps 1-30 s apart, all using span- format. Groups by (run_id, input, output)
    // and collapses events within a 30-second window into one, preferring the event that
    // has token accounting data; among ties, keeping the earliest timestamp.
    static func removeTimeWindowDuplicates(_ events: [TokenUsageEvent]) -> [TokenUsageEvent] {
        struct GroupKey: Hashable {
            let runID: String; let inputTokens: Int; let outputTokens: Int
        }
        var noRunID = [TokenUsageEvent]()
        var grouped = [GroupKey: [TokenUsageEvent]]()
        for event in events {
            guard !event.runID.isEmpty else { noRunID.append(event); continue }
            let key = GroupKey(runID: event.runID, inputTokens: event.inputTokens, outputTokens: event.outputTokens)
            grouped[key, default: []].append(event)
        }
        var kept = [TokenUsageEvent]()
        for var group in grouped.values {
            group.sort { isTimestamp($0.createdAt, before: $1.createdAt) }
            var windowStart = 0
            for i in 1..<group.count {
                guard let t0 = ISO8601DateFormatter.parseTokenUsageDate(from: group[i - 1].createdAt),
                      let t1 = ISO8601DateFormatter.parseTokenUsageDate(from: group[i].createdAt),
                      t1.timeIntervalSince(t0) <= 30
                else {
                    let window = group[windowStart..<i]
                    kept.append(preferredDuplicate(in: window))
                    windowStart = i
                    continue
                }
            }
            kept.append(preferredDuplicate(in: group[windowStart...]))
        }
        return kept + noRunID
    }

    static func preferredDuplicate(_ lhs: TokenUsageEvent, _ rhs: TokenUsageEvent) -> TokenUsageEvent {
        if lhs.tokenAccounting == nil, rhs.tokenAccounting != nil { return rhs }
        return lhs
    }

    private static func preferredDuplicate(in window: some Collection<TokenUsageEvent>) -> TokenUsageEvent {
        window.first(where: { $0.tokenAccounting != nil }) ?? window.first!
    }

    static func timestampsAreWithinThirtySeconds(_ lhs: String, _ rhs: String) -> Bool {
        guard let lhsDate = ISO8601DateFormatter.parseTokenUsageDate(from: lhs),
              let rhsDate = ISO8601DateFormatter.parseTokenUsageDate(from: rhs)
        else {
            return lhs == rhs
        }
        return abs(lhsDate.timeIntervalSince(rhsDate)) <= 30
    }
}

extension PrivateUsageDailyBucketBuilder {
    static func eventPrecedes(_ lhs: TokenUsageEvent, _ rhs: TokenUsageEvent) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return isTimestamp(lhs.createdAt, before: rhs.createdAt)
        }
        if lhs.runID != rhs.runID {
            return lhs.runID < rhs.runID
        }
        if lhs.spanID != rhs.spanID {
            return lhs.spanID < rhs.spanID
        }
        if lhs.aiTool.rawValue != rhs.aiTool.rawValue {
            return lhs.aiTool.rawValue < rhs.aiTool.rawValue
        }
        if lhs.model != rhs.model {
            return lhs.model < rhs.model
        }
        if lhs.taskType.rawValue != rhs.taskType.rawValue {
            return lhs.taskType.rawValue < rhs.taskType.rawValue
        }
        if lhs.stage.rawValue != rhs.stage.rawValue {
            return lhs.stage.rawValue < rhs.stage.rawValue
        }
        return lhs.totalTokens < rhs.totalTokens
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
