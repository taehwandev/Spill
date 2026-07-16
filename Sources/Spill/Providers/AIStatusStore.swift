import Combine
import SwiftUI

@MainActor
final class AIStatusStore: ObservableObject {
    typealias Reader = () -> [LocalAIToolStatus]
    typealias BackgroundReader = @Sendable (@escaping @Sendable () -> Bool) -> [LocalAIToolStatus]

    @Published private(set) var statuses: [LocalAIToolStatus]
    @Published private(set) var detectedStatuses: [LocalAIToolStatus]
    @Published private(set) var hasCompletedRefresh = false

    private let reader: Reader
    private let backgroundReader: BackgroundReader
    private var backgroundRefreshTask: Task<Void, Never>?
    private var backgroundRefreshCancellation: LocalAIStatusRefreshCancellation?
    private var isBackgroundRefreshInFlight = false
    private var lastBackgroundRefreshStartedAt: Date?

    private static let minimumBackgroundRefreshInterval: TimeInterval = 5.0

    init(
        statuses: [LocalAIToolStatus] = LocalAIStatusProvider.statuses(environment: [:], processNames: []),
        reader: @escaping Reader = { LocalAIStatusProvider.statuses() },
        backgroundReader: @escaping @Sendable BackgroundReader = { shouldCancel in
            LocalAIStatusProvider.statuses(shouldCancel: shouldCancel)
        }
    ) {
        self.statuses = statuses
        self.detectedStatuses = statuses
        self.reader = reader
        self.backgroundReader = backgroundReader
    }

    var statusCountDidChange: AnyPublisher<Int, Never> {
        $statuses
            .map(\.count)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func refresh() {
        let detectedStatuses = reader()
        self.detectedStatuses = detectedStatuses
        statuses = Self.withOrderedDashboardAgentPlaceholders(detectedStatuses)
        hasCompletedRefresh = true
    }

    func cancelRefresh() {
        backgroundRefreshCancellation?.cancel()
        backgroundRefreshCancellation = nil
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = nil
        isBackgroundRefreshInFlight = false
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
        let cancellation = LocalAIStatusRefreshCancellation()
        backgroundRefreshCancellation = cancellation
        let backgroundReader = backgroundReader
        backgroundRefreshTask = Task { @MainActor [weak self, cancellation] in
            let detectedStatuses = await Task.detached(priority: .utility) {
                backgroundReader { cancellation.isCancelled() }
            }.value

            guard let self else {
                return
            }
            guard self.backgroundRefreshCancellation === cancellation else {
                return
            }
            self.backgroundRefreshCancellation = nil
            self.isBackgroundRefreshInFlight = false

            guard !Task.isCancelled, !cancellation.isCancelled() else {
                return
            }

            self.detectedStatuses = detectedStatuses
            self.statuses = Self.withOrderedDashboardAgentPlaceholders(detectedStatuses)
            self.hasCompletedRefresh = true
        }
    }

    private static func withOrderedDashboardAgentPlaceholders(
        _ detectedStatuses: [LocalAIToolStatus]
    ) -> [LocalAIToolStatus] {
        let dashboardStatuses = LocalAIToolKind.allCases
            .filter(\.isTokenDashboardAgentTool)
            .map { kind in
                detectedStatuses.first { $0.kind == kind } ?? LocalAIToolStatus(
                    kind: kind,
                    value: "Ready",
                    subtitle: "Ready locally",
                    state: .normal
                )
            }
        let otherStatuses = detectedStatuses.filter { !$0.kind.isTokenDashboardAgentTool }
        return dashboardStatuses + otherStatuses
    }
}

private final class LocalAIStatusRefreshCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.withLock {
            cancelled = true
        }
    }

    func isCancelled() -> Bool {
        lock.withLock { cancelled }
    }
}
