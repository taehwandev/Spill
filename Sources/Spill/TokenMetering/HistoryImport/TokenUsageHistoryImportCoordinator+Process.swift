import Foundation

extension TokenUsageHistoryImportCoordinator {
    func noHistoryResult(
        mode: TokenUsageHistoryImportMode,
        firstImportMessage: String,
        incrementalMessage: String
    ) -> TokenUsageHistoryToolResult {
        switch mode {
        case .firstImport:
            return .unavailable(firstImportMessage)
        case .incremental:
            return .completed(
                scannedSources: 0,
                importedEvents: 0,
                skippedDuplicates: 0,
                unsupportedRecords: 0,
                message: incrementalMessage
            )
        }
    }

    func historyArguments(for mode: TokenUsageHistoryImportMode) -> [String] {
        switch mode {
        case .firstImport:
            return ["--all"]
        case .incremental:
            return ["--since-hours", "\(Self.incrementalLookbackHours)"]
        }
    }

    func runProcess(
        executableURL: URL,
        arguments: [String],
        environment: [String: String] = [:]
    ) -> TokenUsageHistoryImportProcessResult {
        let context = TokenUsageHistoryImportProcessContext(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            store: store,
            maximumRuntime: Self.maximumProcessRuntime,
            shouldCancel: { [weak self] in
                self?.isCancelled ?? true
            },
            processDidStart: { [weak self] process in
                self?.processLock.withLock {
                    self?.runningProcess = process
                }
            },
            processDidFinish: { [weak self] in
                self?.processLock.withLock {
                    self?.runningProcess = nil
                }
            }
        )
        return processRunner(context)
    }

    static func defaultHistoryStateDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Spill/token-metering/history-import", isDirectory: true)
    }

    static func preferredHistoryImportScriptURL(
        bundledURL: URL?,
        installedURL: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        if let bundledURL, fileManager.fileExists(atPath: bundledURL.path) {
            return bundledURL
        }
        if fileManager.fileExists(atPath: installedURL.path) {
            return installedURL
        }
        return bundledURL
    }

    var isCancelled: Bool {
        lock.withLock {
            isCancellationRequested
        }
    }

    func publishToolState(
        _ tool: TokenUsageHistoryImportTool,
        state: TokenUsageHistoryImportToolState,
        message: String?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            var nextSnapshot = self.snapshot
            guard let index = nextSnapshot.tools.firstIndex(where: { $0.tool == tool }) else {
                return
            }
            nextSnapshot.tools[index].state = state
            nextSnapshot.tools[index].message = message
            self.snapshot = nextSnapshot
        }
    }

}
