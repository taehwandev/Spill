import Foundation

extension TokenUsageHistoryImportCoordinator {
    func publishToolSnapshot(
        _ tool: TokenUsageHistoryImportTool,
        result: TokenUsageHistoryToolResult,
        finishedAt: Date,
        successfulAt: Date?
    ) {
        let lastRun = TokenUsageHistoryImportLastRunSnapshot(
            finishedAt: finishedAt,
            state: result.state,
            scannedSources: result.scannedSources,
            importedEvents: result.importedEvents,
            skippedDuplicates: result.skippedDuplicates,
            unsupportedRecords: result.unsupportedRecords,
            message: result.message
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            var nextSnapshot = self.snapshot
            guard let index = nextSnapshot.tools.firstIndex(where: { $0.tool == tool }) else {
                return
            }
            nextSnapshot.tools[index].state = result.state
            nextSnapshot.tools[index].scannedSources = result.scannedSources
            nextSnapshot.tools[index].importedEvents = result.importedEvents
            nextSnapshot.tools[index].skippedDuplicates = result.skippedDuplicates
            nextSnapshot.tools[index].unsupportedRecords = result.unsupportedRecords
            nextSnapshot.tools[index].message = result.message
            nextSnapshot.tools[index].lastSuccessfulImportAt = successfulAt
                ?? self.stateStore.lastSuccessfulImportAt(for: tool)
            nextSnapshot.tools[index].lastRun = lastRun
            self.snapshot = nextSnapshot
        }
    }

    static func fullHistoryToolPlans(
        tools: [TokenUsageHistoryImportTool]
    ) -> [TokenUsageHistoryImportTool: TokenUsageHistoryImportMode] {
        Dictionary(
            uniqueKeysWithValues: tools.map { tool in
                (tool, .firstImport)
            }
        )
    }


    static func makeIdleSnapshot(
        stateStore: TokenUsageHistoryImportStateStore
    ) -> TokenUsageHistoryImportSnapshot {
        TokenUsageHistoryImportSnapshot(
            isRunning: false,
            startedAt: nil,
            finishedAt: nil,
            tools: TokenUsageHistoryImportTool.allCases.map { tool in
                .pending(
                    tool: tool,
                    mode: .firstImport,
                    lastSuccessfulImportAt: stateStore.lastSuccessfulImportAt(for: tool),
                    lastRun: stateStore.lastRun(for: tool)
                )
            }
        )
    }

    func snapshotWithUpdatedTools(
        startedAt: Date?,
        finishedAt: Date?,
        isRunning: Bool,
        update: (TokenUsageHistoryImportToolSnapshot) -> TokenUsageHistoryImportToolSnapshot
    ) -> TokenUsageHistoryImportSnapshot {
        TokenUsageHistoryImportSnapshot(
            isRunning: isRunning,
            startedAt: startedAt,
            finishedAt: finishedAt,
            tools: snapshot.tools.map(update)
        )
    }

}
