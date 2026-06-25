import Foundation

final class TokenUsageCollectorCoordinator: TokenUsageExternalCollecting, @unchecked Sendable {
    typealias AntigravityImportRunner = (
        TokenUsageStore,
        Date,
        @escaping () -> Bool
    ) -> TokenUsageAntigravityImportSummary

    static let collectionDidFinishNotification = Notification.Name("app.spill.token-usage-collector.collection-did-finish")

    private let store: TokenUsageStore
    private let antigravityImportRunner: AntigravityImportRunner
    private let antigravityLookbackInterval: TimeInterval
    private let queue = DispatchQueue(label: "app.spill.token-usage-collector")
    private let lock = NSLock()
    private var isCollecting = false
    private var hasPendingRequest = false
    private var isStopping = false

    init(
        store: TokenUsageStore,
        antigravityImportRunner: AntigravityImportRunner? = nil,
        antigravityLookbackInterval: TimeInterval = 24 * 60 * 60
    ) {
        self.store = store
        self.antigravityImportRunner = antigravityImportRunner ?? { store, startDate, shouldCancel in
            TokenUsageAntigravityImporter().importRecentEvents(
                into: store,
                since: startDate,
                shouldCancel: shouldCancel
            )
        }
        self.antigravityLookbackInterval = antigravityLookbackInterval
    }

    func requestCollection(reason: String) {
        let shouldStart = lock.withLock {
            guard !isStopping else {
                return false
            }
            if isCollecting {
                hasPendingRequest = true
                return false
            }

            isCollecting = true
            return true
        }

        guard shouldStart else {
            return
        }

        queue.async { [weak self] in
            self?.runCollectionLoop()
        }
    }

    func stop() {
        lock.withLock {
            isStopping = true
            hasPendingRequest = false
        }
    }

    private func runCollectionLoop() {
        while true {
            guard !shouldStop else {
                finishCollection()
                return
            }

            // The collector only drains app-owned queued events. Local runtime
            // history scans are user-initiated through TokenUsageHistoryImportCoordinator.
            // AGY is different: it has no runtime hook, so its active importer is
            // the real-time local collection path.
            drainQueuedInbox()

            guard !shouldStop else {
                finishCollection()
                return
            }

            runAntigravityActiveImporter()

            let shouldRunAgain = lock.withLock {
                if isStopping {
                    hasPendingRequest = false
                    isCollecting = false
                    return false
                }
                if hasPendingRequest {
                    hasPendingRequest = false
                    return true
                }

                isCollecting = false
                return false
            }

            if !shouldRunAgain {
                finishCollection()
                return
            }
        }
    }

    private func runAntigravityActiveImporter() {
        let startDate = Date().addingTimeInterval(-antigravityLookbackInterval)
        _ = antigravityImportRunner(store, startDate) { [weak self] in
            self?.shouldStop ?? true
        }
    }

    private func drainQueuedInbox() {
        guard !shouldStop else {
            return
        }
        store.drainQueuedEventsWithoutLoading(
            scheduleFollowUpDrain: { [weak self] in
                guard let self, !self.shouldStop else { return }
                queue.asyncAfter(deadline: .now() + .milliseconds(25)) { [weak self] in
                    guard let self, !self.shouldStop else { return }
                    self.drainQueuedInbox()
                }
            }
        )
    }

    private var shouldStop: Bool {
        lock.withLock { isStopping }
    }

    private func finishCollection() {
        lock.withLock {
            isCollecting = false
            hasPendingRequest = false
        }
        NotificationCenter.default.post(name: Self.collectionDidFinishNotification, object: self)
    }

}
