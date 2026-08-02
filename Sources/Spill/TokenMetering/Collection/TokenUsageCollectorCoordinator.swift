import Foundation

final class TokenUsageCollectorCoordinator: TokenUsageExternalCollecting, @unchecked Sendable {
    private enum PostPassAction {
        case runAgain
        case finish([@Sendable () -> Void])
    }

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
    typealias FinalizationBoundaryHook = @Sendable () -> Void

    static let collectionDidFinishNotification = Notification.Name("app.spill.token-usage-collector.collection-did-finish")

    /// Reasons tied to an explicit user action or a correctness-critical read.
    /// These bypass the per-importer pacing floor; periodic timer reasons
    /// (`dashboard_refresh`, `menu_bar_status`) do not, so back-to-back timer
    /// requests coalesce into inbox drains instead of full importer re-runs.
    static let importerForcingReasons: Set<String> = [
        "app_launch",
        "panel_open",
        "manual_refresh",
        "private_usage_upload",
    ]

    private let store: TokenUsageStore
    private let antigravityImportRunner: AntigravityImportRunner
    private let claudeCodeImportRunner: ClaudeCodeImportRunner
    private let antigravityLookbackInterval: TimeInterval
    private let activeImporterMinimumInterval: TimeInterval
    private let now: () -> Date
    private let finalizationBoundaryHook: FinalizationBoundaryHook?
    private let queue = DispatchQueue(label: "app.spill.token-usage-collector")
    private let lock = NSLock()
    private var isCollecting = false
    private var hasPendingRequest = false
    private var pendingRequestForcesImporters = false
    private var currentRequestForcesImporters = false
    private var lastAntigravityImportAt: Date?
    private var lastClaudeCodeImportAt: Date?
    private var isStopping = false
    private var collectionCompletionHandlers: [@Sendable () -> Void] = []

    init(
        store: TokenUsageStore,
        antigravityImportRunner: AntigravityImportRunner? = nil,
        antigravityLookbackInterval: TimeInterval = 24 * 60 * 60,
        claudeCodeImportRunner: ClaudeCodeImportRunner? = nil,
        activeImporterMinimumInterval: TimeInterval = 30,
        now: @escaping () -> Date = Date.init,
        finalizationBoundaryHook: FinalizationBoundaryHook? = nil
    ) {
        self.activeImporterMinimumInterval = activeImporterMinimumInterval
        self.now = now
        self.finalizationBoundaryHook = finalizationBoundaryHook
        self.store = store
        self.antigravityImportRunner = antigravityImportRunner ?? { store, startDate, shouldCancel in
            TokenUsageAntigravityImporter().importRecentEvents(
                into: store,
                since: startDate,
                shouldCancel: shouldCancel
            )
        }
        self.antigravityLookbackInterval = antigravityLookbackInterval
        if let claudeCodeImportRunner {
            self.claudeCodeImportRunner = claudeCodeImportRunner
        } else {
            let importer = TokenUsageClaudeCodeImporter()
            self.claudeCodeImportRunner = { store, shouldCancel in
                importer.importRecentSessions(
                    into: store,
                    shouldCancel: shouldCancel
                )
            }
        }
    }
}

extension TokenUsageCollectorCoordinator {
    func requestCollection(reason: String) {
        requestCollection(reason: reason, completion: nil)
    }

    func requestCollectionAndWait(reason: String) async {
        await withCheckedContinuation { continuation in
            requestCollection(reason: reason) {
                continuation.resume()
            }
        }
    }

    func requestCollection(reason: String, completion: (@Sendable () -> Void)?) {
        let forcesImporters = Self.importerForcingReasons.contains(reason)
        var completionToRun: (@Sendable () -> Void)?
        let shouldStart = lock.withLock {
            guard !isStopping else {
                completionToRun = completion
                return false
            }
            if let completion {
                collectionCompletionHandlers.append(completion)
            }
            if isCollecting {
                // Concurrent requests merge into one follow-up pass instead of
                // queueing one full re-run each; force-ness is sticky so a manual
                // request arriving mid-collection still gets a forced pass.
                hasPendingRequest = true
                pendingRequestForcesImporters = pendingRequestForcesImporters || forcesImporters
                return false
            }

            isCollecting = true
            currentRequestForcesImporters = forcesImporters
            return true
        }

        guard shouldStart else {
            completionToRun?()
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
}

extension TokenUsageCollectorCoordinator {
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

            let postPassAction = lock.withLock {
                if !isStopping, hasPendingRequest {
                    hasPendingRequest = false
                    currentRequestForcesImporters = pendingRequestForcesImporters
                    pendingRequestForcesImporters = false
                    return PostPassAction.runAgain
                }

                return PostPassAction.finish(prepareToFinishCollectionLocked())
            }

            switch postPassAction {
            case .runAgain:
                continue
            case let .finish(completions):
                finalizationBoundaryHook?()
                completeCollection(completions)
                return
            }
        }
    }
}

extension TokenUsageCollectorCoordinator {
    private func runAntigravityActiveImporter() {
        guard shouldRunImporter(lastImportAt: \.lastAntigravityImportAt) else {
            return
        }
        let startDate = now().addingTimeInterval(-antigravityLookbackInterval)
        _ = antigravityImportRunner(store, startDate) { [weak self] in
            self?.shouldStop ?? true
        }
        lock.withLock { lastAntigravityImportAt = now() }
    }

    private func runClaudeCodeActiveImporter() {
        guard shouldRunImporter(lastImportAt: \.lastClaudeCodeImportAt) else {
            return
        }
        _ = claudeCodeImportRunner(store) { [weak self] in
            self?.shouldStop ?? true
        }
        lock.withLock { lastClaudeCodeImportAt = now() }
    }

    /// Timer-paced requests run an importer only after its minimum interval has
    /// elapsed; the inbox drain above stays unthrottled, so hook-written events
    /// keep importing immediately. Forced reasons always run every importer.
    private func shouldRunImporter(
        lastImportAt: KeyPath<TokenUsageCollectorCoordinator, Date?>
    ) -> Bool {
        lock.withLock {
            if currentRequestForcesImporters {
                return true
            }
            guard let lastRunDate = self[keyPath: lastImportAt] else {
                return true
            }
            let elapsed = now().timeIntervalSince(lastRunDate)
            return elapsed < 0 || elapsed >= activeImporterMinimumInterval
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
        let completions = lock.withLock {
            prepareToFinishCollectionLocked()
        }
        completeCollection(completions)
    }

    /// Must be called while holding `lock`. Detaching the current completion
    /// batch in the same critical section as the idle transition prevents a
    /// newly accepted request from being cleared or completed by the old pass.
    private func prepareToFinishCollectionLocked() -> [@Sendable () -> Void] {
        isCollecting = false
        hasPendingRequest = false
        pendingRequestForcesImporters = false
        currentRequestForcesImporters = false
        let completions = collectionCompletionHandlers
        collectionCompletionHandlers.removeAll()
        return completions
    }

    private func completeCollection(_ completions: [@Sendable () -> Void]) {
        for completion in completions {
            completion()
        }
        NotificationCenter.default.post(name: Self.collectionDidFinishNotification, object: self)
    }
}
