import Foundation

final class TokenUsageCollectorCoordinator: TokenUsageExternalCollecting, @unchecked Sendable {
    typealias AntigravityImportRunner = (
        TokenUsageStore,
        Date,
        @escaping () -> Bool
    ) -> TokenUsageAntigravityImportSummary
    // Claude uses byte-offset cursors inside transcript files, so collection can
    // scan all known sessions while importing only newly appended turns.
    typealias ClaudeCodeImportRunner = (
        TokenUsageStore,
        @escaping () -> Bool
    ) -> TokenUsageClaudeCodeImportSummary

    static let collectionDidFinishNotification = Notification.Name("app.spill.token-usage-collector.collection-did-finish")

    private let store: TokenUsageStore
    private let antigravityImportRunner: AntigravityImportRunner
    private let claudeCodeImportRunner: ClaudeCodeImportRunner
    private let antigravityLookbackInterval: TimeInterval
    private let queue = DispatchQueue(label: "app.spill.token-usage-collector")
    private let lock = NSLock()
    private var isCollecting = false
    private var hasPendingRequest = false
    private var isStopping = false

    init(
        store: TokenUsageStore,
        antigravityImportRunner: AntigravityImportRunner? = nil,
        antigravityLookbackInterval: TimeInterval = 24 * 60 * 60,
        claudeCodeImportRunner: ClaudeCodeImportRunner? = nil
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
        self.claudeCodeImportRunner = claudeCodeImportRunner ?? { store, shouldCancel in
            TokenUsageClaudeCodeImporter().importRecentSessions(
                into: store,
                shouldCancel: shouldCancel
            )
        }
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

            // Drain app-owned queued inbox events (Stop hook writes, history imports).
            // AGY and Claude Code use native active importers that write directly to
            // the store, so they do not produce inbox files.
            drainQueuedInbox()

            guard !shouldStop else {
                finishCollection()
                return
            }

            runAntigravityActiveImporter()

            guard !shouldStop else {
                finishCollection()
                return
            }

            runClaudeCodeActiveImporter()

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

    private func runClaudeCodeActiveImporter() {
        _ = claudeCodeImportRunner(store) { [weak self] in
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
