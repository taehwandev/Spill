import Foundation

struct TokenUsageDashboardContextCacheKey: Equatable {
    let eventCount: Int
    let firstSpanID: String?
    let firstCreatedAt: String?
    let lastSpanID: String?
    let lastCreatedAt: String?
    let totalTokens: Int
    let eventFingerprint: Int
    let showAdvancedTools: Bool
    let visibleAITools: [String]?
    let calendarIdentifier: String
    let calendarTimeZone: String
    let firstWeekday: Int

    init(events: [TokenUsageEvent], request: TokenUsageDashboardBuildRequest) {
        eventCount = events.count
        firstSpanID = events.first?.spanID
        firstCreatedAt = events.first?.createdAt
        lastSpanID = events.last?.spanID
        lastCreatedAt = events.last?.createdAt
        var total = 0
        var hasher = Hasher()
        for event in events {
            total += event.totalTokens
            hasher.combine(event.spanID)
            hasher.combine(event.createdAt)
            hasher.combine(event.aiTool.rawValue)
            hasher.combine(event.totalTokens)
            hasher.combine(event.inputTokens)
            hasher.combine(event.outputTokens)
            hasher.combine(event.tokenAccounting?.uncachedInputTokens)
        }
        totalTokens = total
        eventFingerprint = hasher.finalize()
        showAdvancedTools = request.showAdvancedTools
        visibleAITools = request.visibleAITools?.map(\.rawValue).sorted()
        calendarIdentifier = String(describing: request.calendar.identifier)
        calendarTimeZone = request.calendar.timeZone.identifier
        firstWeekday = request.calendar.firstWeekday
    }
}
