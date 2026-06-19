import Foundation

struct TokenUsageClearPreview: Equatable {
    let scopeTitle: String
    let eventCount: Int
    let totalTokens: Int

    var hasEvents: Bool {
        eventCount > 0
    }
}
