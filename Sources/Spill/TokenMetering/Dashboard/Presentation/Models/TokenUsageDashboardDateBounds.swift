import Foundation

struct TokenUsageDashboardDateBounds: Equatable {
    let earliest: Date?
    let latest: Date?

    static let empty = TokenUsageDashboardDateBounds(earliest: nil, latest: nil)
}
