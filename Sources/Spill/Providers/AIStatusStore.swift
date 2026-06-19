import SwiftUI

@MainActor
final class AIStatusStore: ObservableObject {
    typealias Reader = () -> [LocalAIToolStatus]

    @Published private(set) var statuses: [LocalAIToolStatus]

    private let reader: Reader
    private var backgroundRefreshTask: Task<Void, Never>?
    private var isBackgroundRefreshInFlight = false
    private var lastBackgroundRefreshStartedAt: Date?

    private static let minimumBackgroundRefreshInterval: TimeInterval = 3.0

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
        let now = Date()
        guard !isBackgroundRefreshInFlight else {
            return
        }
        if let lastBackgroundRefreshStartedAt,
           now.timeIntervalSince(lastBackgroundRefreshStartedAt) < Self.minimumBackgroundRefreshInterval {
            return
        }

        isBackgroundRefreshInFlight = true
        lastBackgroundRefreshStartedAt = now
        backgroundRefreshTask = Task { @MainActor [weak self] in
            let statuses = await Task.detached(priority: .utility) {
                LocalAIStatusProvider.statuses()
            }.value

            guard let self else {
                return
            }
            self.isBackgroundRefreshInFlight = false

            guard !Task.isCancelled else {
                return
            }

            self.statuses = statuses
        }
    }
}
