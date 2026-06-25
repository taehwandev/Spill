import Foundation

extension TokenUsageHistoryImportCoordinator {
    func runImport(
        tools selectedTools: [TokenUsageHistoryImportTool],
        toolPlans: [TokenUsageHistoryImportTool: TokenUsageHistoryImportMode]
    ) {
        for tool in selectedTools {
            guard !isCancelled else {
                let result = TokenUsageHistoryToolResult.cancelled("Cancelled before this importer started.")
                let finishedAt = Date()
                stateStore.recordLastRun(for: tool, result: result, at: finishedAt)
                publishToolSnapshot(tool, result: result, finishedAt: finishedAt, successfulAt: nil)
                continue
            }

            let mode = toolPlans[tool] ?? .firstImport
            publishToolState(tool, state: .running, message: nil)
            let result = runToolImport(tool, mode: mode)
            reportFailureIfNeeded(tool, mode: mode, result: result)

            let finishedAt = Date()
            let successfulAt = result.state == .completed ? finishedAt : nil
            if let successfulAt {
                stateStore.markSuccessfulImport(for: tool, mode: mode, at: successfulAt)
            }
            stateStore.recordLastRun(for: tool, result: result, at: finishedAt)
            if result.state == .completed {
                store.drainQueuedEventsWithoutLoading(maximumInboxEventCount: nil)
            }
            publishToolSnapshot(tool, result: result, finishedAt: finishedAt, successfulAt: successfulAt)
        }

        store.drainQueuedEventsWithoutLoading(maximumInboxEventCount: nil)
        store.notifyEventsDidChange()
        let finishedAt = Date()
        lock.withLock {
            isImportRunning = false
            isCancellationRequested = false
        }
        processLock.withLock {
            runningProcess = nil
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            var nextSnapshot = self.snapshot
            nextSnapshot.isRunning = false
            nextSnapshot.finishedAt = finishedAt
            self.snapshot = nextSnapshot
        }
    }

    func runToolImport(
        _ tool: TokenUsageHistoryImportTool,
        mode: TokenUsageHistoryImportMode
    ) -> TokenUsageHistoryToolResult {
        switch tool {
        case .codex:
            return runCodexImport(mode: mode)
        case .claude:
            return runClaudeImport(mode: mode)
        case .antigravity:
            return runAntigravityImport(mode: mode)
        }
    }

    func reportFailureIfNeeded(
        _ tool: TokenUsageHistoryImportTool,
        mode: TokenUsageHistoryImportMode,
        result: TokenUsageHistoryToolResult
    ) {
        guard result.state == .failed else {
            return
        }

        failureReporter(tool, mode, result)
    }

}
