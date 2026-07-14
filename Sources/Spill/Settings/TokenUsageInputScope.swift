import Foundation

enum TokenUsageInputScope: String, CaseIterable, Sendable {
    case includeCache = "include-cache"
    case freshOnly = "fresh-only"

    static func normalized(rawValue: String?) -> Self {
        Self(rawValue: rawValue ?? "") ?? .includeCache
    }
}
