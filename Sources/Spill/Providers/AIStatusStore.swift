import SwiftUI

@MainActor
final class AIStatusStore: ObservableObject {
    typealias Reader = () -> [LocalAIToolStatus]

    @Published private(set) var statuses: [LocalAIToolStatus]

    private let reader: Reader
    private var backgroundRefreshTask: Task<Void, Never>?

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

    func refreshInBackground() {
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = Task { @MainActor [weak self] in
            let statuses = await Task.detached(priority: .utility) {
                LocalAIStatusProvider.statuses()
            }.value

            guard !Task.isCancelled else {
                return
            }

            self?.statuses = statuses
        }
    }
}
