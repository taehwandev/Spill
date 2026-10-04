import Combine
import SwiftUI

@MainActor
final class AIStatusStore: ObservableObject {
    typealias Reader = (Set<LocalAIToolKind>) -> [LocalAIToolStatus]
    typealias BackgroundReader = @Sendable (Set<LocalAIToolKind>, @escaping @Sendable () -> Bool) -> [LocalAIToolStatus]

    @Published private(set) var statuses: [LocalAIToolStatus]
    @Published private(set) var detectedStatuses: [LocalAIToolStatus]
    @Published private(set) var hasCompletedRefresh = false

    private let reader: Reader
    private let backgroundReader: BackgroundReader
    private var backgroundRefreshTask: Task<Void, Never>?
    private var backgroundRefreshCancellation: LocalAIStatusRefreshCancellation?
    private var isBackgroundRefreshInFlight = false
    private var lastBackgroundRefreshStartedAt: Date?
    private var enabledKinds = TokenMeteringToolAvailability.supportedLocalToolKindSet

    static let minimumBackgroundRefreshInterval: TimeInterval = 15.0

    init(
        statuses: [LocalAIToolStatus] = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            enabledKinds: TokenMeteringToolAvailability.supportedLocalToolKindSet
        ),
        reader: @escaping Reader = { enabledKinds in
            LocalAIStatusProvider.statuses(enabledKinds: enabledKinds)
        },
        backgroundReader: @escaping BackgroundReader = { enabledKinds, shouldCancel in
            LocalAIStatusProvider.statuses(enabledKinds: enabledKinds, shouldCancel: shouldCancel)
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
        let detectedStatuses = enabledKinds.isEmpty ? [] : reader(enabledKinds)
        apply(detectedStatuses: detectedStatuses)
    }

    func setEnabledKinds(_ kinds: Set<LocalAIToolKind>) {
        guard enabledKinds != kinds else {
            return
        }

        cancelRefresh()
        enabledKinds = kinds
        lastBackgroundRefreshStartedAt = nil
        apply(detectedStatuses: detectedStatuses.filter { kinds.contains($0.kind) })
    }

    func cancelRefresh() {
        backgroundRefreshCancellation?.cancel()
        backgroundRefreshCancellation = nil
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = nil
        isBackgroundRefreshInFlight = false
    }

    func refreshInBackground() {
        guard !enabledKinds.isEmpty else {
            apply(detectedStatuses: [])
            return
        }
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
        let enabledKinds = enabledKinds
        backgroundRefreshTask = Task { @MainActor [weak self, cancellation] in
            let detectedStatuses = await Task.detached(priority: .utility) {
                backgroundReader(enabledKinds) { cancellation.isCancelled() }
            }.value

            guard let self else {
                return
            }
            guard self.backgroundRefreshCancellation === cancellation else {
                return
            }
            self.backgroundRefreshCancellation = nil
            self.backgroundRefreshTask = nil
            self.isBackgroundRefreshInFlight = false

            guard !Task.isCancelled, !cancellation.isCancelled() else {
                return
            }

            self.apply(detectedStatuses: detectedStatuses)
        }
    }

    private func apply(detectedStatuses nextDetectedStatuses: [LocalAIToolStatus]) {
        let filteredDetectedStatuses = nextDetectedStatuses.filter { enabledKinds.contains($0.kind) }
        let nextStatuses = Self.withOrderedDashboardAgentPlaceholders(
            filteredDetectedStatuses,
            enabledKinds: enabledKinds
        )
        if detectedStatuses != filteredDetectedStatuses {
            detectedStatuses = filteredDetectedStatuses
        }
        if statuses != nextStatuses {
            statuses = nextStatuses
        }
        if !hasCompletedRefresh {
            hasCompletedRefresh = true
        }
    }

    private static func withOrderedDashboardAgentPlaceholders(
        _ detectedStatuses: [LocalAIToolStatus],
        enabledKinds: Set<LocalAIToolKind>
    ) -> [LocalAIToolStatus] {
        let dashboardStatuses = LocalAIToolKind.allCases
            .filter { $0.isTokenDashboardAgentTool && enabledKinds.contains($0) }
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
