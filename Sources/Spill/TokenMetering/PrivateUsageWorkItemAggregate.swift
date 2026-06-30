import Foundation

struct PrivateUsageWorkItemAggregate: Codable, Equatable, Sendable {
    let id: String
    let aiTool: String
    let taskType: String
    let stage: String
    let model: String
    var totals: PrivateUsageTokenTotals
    var firstEventAt: String
    var lastEventAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case aiTool = "ai_tool"
        case taskType = "task_type"
        case stage
        case model
        case totals
        case firstEventAt = "first_event_at"
        case lastEventAt = "last_event_at"
    }

    init(
        id: String,
        aiTool: String,
        taskType: String,
        stage: String,
        model: String,
        totals: PrivateUsageTokenTotals,
        firstEventAt: String,
        lastEventAt: String
    ) {
        self.id = id
        self.aiTool = aiTool
        self.taskType = taskType
        self.stage = stage
        self.model = model
        self.totals = totals
        self.firstEventAt = firstEventAt
        self.lastEventAt = lastEventAt
    }

    mutating func add(_ event: TokenUsageEvent) {
        totals.add(event)
        if Self.isTimestamp(event.createdAt, before: firstEventAt) {
            firstEventAt = event.createdAt
        }
        if Self.isTimestamp(lastEventAt, before: event.createdAt) {
            lastEventAt = event.createdAt
        }
    }
}

private extension PrivateUsageWorkItemAggregate {
    static func isTimestamp(_ lhs: String, before rhs: String) -> Bool {
        guard let lhsDate = ISO8601DateFormatter.parseTokenUsageDate(from: lhs),
              let rhsDate = ISO8601DateFormatter.parseTokenUsageDate(from: rhs)
        else {
            return lhs < rhs
        }

        return lhsDate < rhsDate
    }
}
