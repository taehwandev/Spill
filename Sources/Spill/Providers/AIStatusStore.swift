import SwiftUI

@MainActor
final class AIStatusStore: ObservableObject {
    typealias Reader = () -> [LocalAIToolStatus]

    @Published private(set) var statuses: [LocalAIToolStatus]

    private let reader: Reader

    init(
        statuses: [LocalAIToolStatus] = LocalAIStatusProvider.statuses(environment: [:], processNames: []),
        reader: @escaping Reader = { LocalAIStatusProvider.statuses() }
    ) {
        self.statuses = statuses
        self.reader = reader
    }

    func refresh() {
        statuses = reader()
    }
}
