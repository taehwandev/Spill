import Foundation

extension PrivateUsageDailyBucketBuilder {
    static func deduplicateBySpanID(_ events: [TokenUsageEvent]) -> [TokenUsageEvent] {
        // The local store identifies exact usage events by their trusted span ID.
        // Matching counts or timestamps never establish that two events are the same.
        var bestBySpanID = [String: TokenUsageEvent]()
        var withoutSpanID = [TokenUsageEvent]()

        for event in events {
            guard !event.spanID.isEmpty else {
                withoutSpanID.append(event)
                continue
            }
            if let existing = bestBySpanID[event.spanID] {
                bestBySpanID[event.spanID] = preferredDuplicate(existing, event)
            } else {
                bestBySpanID[event.spanID] = event
            }
        }

        return (Array(bestBySpanID.values) + withoutSpanID).sorted(by: eventPrecedes)
    }
}

extension PrivateUsageDailyBucketBuilder {
    static func preferredDuplicate(_ lhs: TokenUsageEvent, _ rhs: TokenUsageEvent) -> TokenUsageEvent {
        if lhs.tokenAccounting == nil, rhs.tokenAccounting != nil { return rhs }
        return lhs
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
