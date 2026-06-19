import Foundation

struct TokenUsageLiveUpdateMarker: Equatable {
    let ids: Set<String>
    let sequence: Int

    static let empty = TokenUsageLiveUpdateMarker(ids: [], sequence: 0)

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }
}
