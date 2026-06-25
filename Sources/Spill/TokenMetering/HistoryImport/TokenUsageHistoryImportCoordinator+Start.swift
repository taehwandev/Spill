import Foundation

extension TokenUsageHistoryImportCoordinator {
    func startImport() {
        startImport(for: TokenUsageHistoryImportTool.allCases)
    }

    func startImport(for tool: TokenUsageHistoryImportTool) {
        startImport(for: [tool])
    }

    func startImport(for requestedTools: [TokenUsageHistoryImportTool]) {
        let selectedTools = TokenUsageHistoryImportTool.allCases.filter { tool in
            requestedTools.contains(tool)
        }
        guard !selectedTools.isEmpty else {
            return
        }

        let shouldStart = lock.withLock {
            guard !isImportRunning else {
                return false
            }
            isImportRunning = true
            isCancellationRequested = false
            return true
        }

        guard shouldStart else {
            return
        }

        do {
            try prepareFullHistoryReconciliation(for: selectedTools)
        } catch {
            lock.withLock {
                isImportRunning = false
                isCancellationRequested = false
            }
            let finishedAt = Date()
            let selectedSet = Set(selectedTools)
            let failedResult = TokenUsageHistoryToolResult.failed(
                "Failed to prepare local token history sync.",
                failureStage: .prepare,
                failureReason: .prepareFailed
            )
            snapshot = snapshotWithUpdatedTools(
                startedAt: finishedAt,
                finishedAt: finishedAt,
                isRunning: false
            ) { current in
                guard selectedSet.contains(current.tool) else {
                    return current
                }
                failureReporter(current.tool, .firstImport, failedResult)
                stateStore.recordLastRun(for: current.tool, result: failedResult, at: finishedAt)
                return TokenUsageHistoryImportToolSnapshot(
                    tool: current.tool,
                    mode: .firstImport,
                    state: .failed,
                    scannedSources: 0,
                    importedEvents: 0,
                    skippedDuplicates: 0,
                    unsupportedRecords: 0,
                    message: failedResult.message,
                    lastSuccessfulImportAt: stateStore.lastSuccessfulImportAt(for: current.tool),
                    lastRun: stateStore.lastRun(for: current.tool)
                )
            }
            return
        }

        let toolPlans = Self.fullHistoryToolPlans(tools: selectedTools)
        let startedAt = Date()
        let selectedSet = Set(selectedTools)
        let initialSnapshot = TokenUsageHistoryImportSnapshot(
            isRunning: true,
            startedAt: startedAt,
            finishedAt: nil,
            tools: snapshot.tools.map { current in
                guard selectedSet.contains(current.tool) else {
                    return current
                }
                return current.preparedForRun(mode: toolPlans[current.tool] ?? .firstImport)
            }
        )

        snapshot = initialSnapshot

        queue.async { [weak self] in
            self?.runImport(tools: selectedTools, toolPlans: toolPlans)
        }
    }

    func cancelImport() {
        lock.withLock {
            isCancellationRequested = true
        }
        processLock.withLock {
            runningProcess?.terminate()
        }
    }

}
