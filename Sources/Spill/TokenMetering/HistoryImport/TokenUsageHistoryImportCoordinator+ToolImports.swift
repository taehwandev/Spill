import Foundation

extension TokenUsageHistoryImportCoordinator {
    func runCodexImport(mode: TokenUsageHistoryImportMode) -> TokenUsageHistoryToolResult {
        guard let importerURL = codexImporterURLProvider(),
              FileManager.default.fileExists(atPath: importerURL.path)
        else {
            return .unavailable("Codex importer is not installed.")
        }
        guard let nodeURL = nodeExecutableURLProvider() else {
            return .failed(
                "Node executable is unavailable.",
                failureStage: .locateRuntime,
                failureReason: .nodeUnavailable
            )
        }

        let arguments = [
            importerURL.path,
            "--state",
            historyStateDirectory.appendingPathComponent("codex-session-import-state.json").path,
            "--label-file",
            historyStateDirectory.appendingPathComponent("codex-label-context.json").path,
            "--reconcile-existing",
        ] + historyArguments(for: mode) + ["--json"]
        let processResult = runProcess(executableURL: nodeURL, arguments: arguments)
        if isCancelled {
            return .cancelled("Cancelled by user.")
        }
        guard processResult.exitCode == 0, !processResult.timedOut else {
            return .failed(
                processResult.timedOut ? "Codex import timed out." : "Codex import failed.",
                failureStage: .process,
                failureReason: processResult.timedOut ? .timeout : .processFailed,
                exitCode: processResult.exitCode,
                timedOut: processResult.timedOut,
                durationSeconds: processResult.durationSeconds
            )
        }

        let summary = ProcessJSONSummary(processResult.stdout)
        guard summary.isValid else {
            return .failed(
                "Codex import did not return a valid summary.",
                failureStage: .parseSummary,
                failureReason: .invalidSummary,
                exitCode: processResult.exitCode,
                timedOut: processResult.timedOut,
                durationSeconds: processResult.durationSeconds
            )
        }
        guard summary.scannedSources > 0 || summary.importedEvents > 0 || summary.skippedDuplicates > 0 else {
            return noHistoryResult(
                mode: mode,
                firstImportMessage: "No Codex local session history was found.",
                incrementalMessage: "No new Codex local history was found in the recent window."
            )
        }

        return .completed(
            scannedSources: summary.scannedSources,
            importedEvents: summary.importedEvents,
            skippedDuplicates: summary.skippedDuplicates,
            unsupportedRecords: summary.unsupportedRecords,
            message: nil
        )
    }

    func runClaudeImport(mode: TokenUsageHistoryImportMode) -> TokenUsageHistoryToolResult {
        guard let hookURL = claudeHookURLProvider(),
              FileManager.default.fileExists(atPath: hookURL.path)
        else {
            return .unavailable("Claude Code importer is not installed.")
        }
        guard let python3URL = python3ExecutableURLProvider() else {
            return .failed(
                "Python 3 executable is unavailable.",
                failureStage: .locateRuntime,
                failureReason: .pythonUnavailable
            )
        }

        let claudeProjectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
        guard FileManager.default.fileExists(atPath: claudeProjectsDir.path) else {
            return .unavailable("No Claude Code local transcript history was found.")
        }

        let arguments = [
            hookURL.path,
            "--scan-dir",
            claudeProjectsDir.path
        ] + historyArguments(for: mode) + ["--json"]
        let processResult = runProcess(
            executableURL: python3URL,
            arguments: arguments,
            environment: [
                "SPILL_TOKEN_USAGE_LABEL_FILE": historyStateDirectory
                    .appendingPathComponent("claude-label-context.json")
                    .path,
                "SPILL_TOKEN_USAGE_SESSION_STATE_DIR": claudeHistorySessionStateDirectory()
                    .path
            ]
        )
        if isCancelled {
            return .cancelled("Cancelled by user.")
        }
        guard processResult.exitCode == 0, !processResult.timedOut else {
            return .failed(
                processResult.timedOut ? "Claude import timed out." : "Claude import failed.",
                failureStage: .process,
                failureReason: processResult.timedOut ? .timeout : .processFailed,
                exitCode: processResult.exitCode,
                timedOut: processResult.timedOut,
                durationSeconds: processResult.durationSeconds
            )
        }

        let summary = ProcessJSONSummary(processResult.stdout)
        guard summary.isValid else {
            return .failed(
                "Claude import did not return a valid summary.",
                failureStage: .parseSummary,
                failureReason: .invalidSummary,
                exitCode: processResult.exitCode,
                timedOut: processResult.timedOut,
                durationSeconds: processResult.durationSeconds
            )
        }
        guard summary.scannedSources > 0 || summary.importedEvents > 0 || summary.skippedDuplicates > 0 else {
            return noHistoryResult(
                mode: mode,
                firstImportMessage: "No Claude Code local transcript history was found.",
                incrementalMessage: "No new Claude Code local transcript history was found in the recent window."
            )
        }

        let result = TokenUsageHistoryToolResult.completed(
            scannedSources: summary.scannedSources,
            importedEvents: summary.importedEvents,
            skippedDuplicates: summary.skippedDuplicates,
            unsupportedRecords: summary.unsupportedRecords,
            message: nil
        )
        syncClaudeHistoryStateToLiveState()
        return result
    }

    // After a Claude history scan the history session-state dir holds the
    // per-transcript (fresh, output, byte_offset) the scan wrote.  The live
    // Stop hook uses a separate session-state dir and may still be behind that
    // position, which would cause the next hook invocation to re-read already-
    // counted turns and produce double-counted events.  Advance any live state
    // file that is behind the matching history state file so the hook resumes
    // exactly where the history scan left off.

    func runAntigravityImport(mode: TokenUsageHistoryImportMode) -> TokenUsageHistoryToolResult {
        let startDate: Date
        switch mode {
        case .firstImport:
            startDate = .distantPast
        case .incremental:
            startDate = Date().addingTimeInterval(-TimeInterval(Self.incrementalLookbackHours) * 3600)
        }

        let summary = antigravityImportRunner(store, startDate) { [weak self] in
            self?.isCancelled ?? true
        }
        if isCancelled {
            return .cancelled("Cancelled by user.")
        }
        if summary.failedToWriteEvents {
            return .failed(
                "Antigravity/AGY import failed while writing usage events.",
                failureStage: .write,
                failureReason: .writeFailed,
                scannedSources: summary.scannedDatabases,
                importedEvents: summary.importedEvents,
                skippedDuplicates: summary.skippedDuplicateEvents,
                unsupportedRecords: summary.unsupportedRecords
            )
        }
        guard summary.scannedDatabases > 0 || summary.importedEvents > 0 || summary.skippedDuplicateEvents > 0 else {
            return noHistoryResult(
                mode: mode,
                firstImportMessage: "No Antigravity/AGY exact usage history was found.",
                incrementalMessage: "No new Antigravity/AGY exact usage history was found in the recent window."
            )
        }

        syncAntigravityHistoryStateToLiveState()
        return .completed(
            scannedSources: summary.scannedDatabases,
            importedEvents: summary.importedEvents,
            skippedDuplicates: summary.skippedDuplicateEvents,
            unsupportedRecords: summary.unsupportedRecords,
            message: nil
        )
    }

}
