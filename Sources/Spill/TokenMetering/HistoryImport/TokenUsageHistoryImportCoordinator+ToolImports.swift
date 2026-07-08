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

        // Full (`--all`) scans reconcile stored events against the freshly written set, so
        // they must read that set before it is drained. The live inbox is watched by
        // TokenUsageInboxMonitor, which triggers a collection drain the instant the Python
        // process writes a file — that would empty the inbox before reconciliation could
        // read it. Route full scans through a private staging inbox the monitor does not
        // watch; reconcile from there, then hand the events to the live inbox for draining.
        let usesStagingInbox = mode == .firstImport
        let stagingInbox = claudeReconcileStagingInboxDirectory()
        // Captured before the (potentially multi-second, hundreds-of-files) scan starts.
        // A live Stop-hook turn for one of the sessions being rescanned can land in the
        // database while the scan is still running, after the scan already read past that
        // transcript file — its span_id would then be legitimately absent from this scan's
        // authoritative set even though it isn't stale. Rows written at or before this
        // cutoff are the only ones reconciliation is allowed to delete.
        let reconciliationCutoffRowID = usesStagingInbox ? store.maxRowID(forAITool: .claude) : 0
        if usesStagingInbox {
            try? FileManager.default.removeItem(at: stagingInbox)
            _ = try? TokenUsageStore.createPrivateDirectoryIfNeeded(at: stagingInbox)
        }

        var environment = [
            "SPILL_TOKEN_USAGE_LABEL_FILE": historyStateDirectory
                .appendingPathComponent("claude-label-context.json")
                .path,
            "SPILL_TOKEN_USAGE_SESSION_STATE_DIR": claudeHistorySessionStateDirectory()
                .path
        ]
        if usesStagingInbox {
            environment["SPILL_TOKEN_USAGE_INBOX_DIR"] = stagingInbox.path
        }

        let arguments = [
            hookURL.path,
            "--scan-dir",
            claudeProjectsDir.path
        ] + historyArguments(for: mode) + ["--json"]
        let processResult = runProcess(
            executableURL: python3URL,
            arguments: arguments,
            environment: environment
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
        reconcileStagedClaudeEventsIfNeeded(
            usesStagingInbox: usesStagingInbox,
            stagingInbox: stagingInbox,
            reconciliationCutoffRowID: reconciliationCutoffRowID
        )
        syncClaudeHistoryStateToLiveState()
        return result
    }

    /// Reconciles full Claude scans only after their staged replacement events
    /// are moved to the live inbox. A full (`--all`) scan is authoritative for
    /// stable span IDs, but deleting stale rows before queuing replacements can
    /// create permanent gaps if a move fails.
    private func reconcileStagedClaudeEventsIfNeeded(
        usesStagingInbox: Bool,
        stagingInbox: URL,
        reconciliationCutoffRowID: Int64
    ) {
        guard usesStagingInbox else { return }

        let authoritative = claudeAuthoritativeSpanIDs(inInbox: stagingInbox)
        let movedRunIDs = moveStagedInboxFilesToLiveInbox(from: stagingInbox)
        let reconcilableAuthoritative = authoritative.filter { movedRunIDs.contains($0.key) }
        if !reconcilableAuthoritative.isEmpty {
            store.reconcileClaudeSessions(
                authoritativeSpanIDsByRun: reconcilableAuthoritative,
                notInsertedAfterRowID: reconciliationCutoffRowID
            )
        }
    }

    func claudeReconcileStagingInboxDirectory() -> URL {
        historyStateDirectory.appendingPathComponent("claude-reconcile-inbox", isDirectory: true)
    }

    /// Reads the Claude events the history scan wrote to `inbox` and groups their span_ids
    /// by run_id. Only `ai_tool == "claude"` records are considered.
    private func claudeAuthoritativeSpanIDs(inInbox inbox: URL) -> [String: Set<String>] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: nil
        ) else {
            return [:]
        }

        var result = [String: Set<String>]()
        for entry in entries where entry.pathExtension == "json" || entry.pathExtension == "jsonl" {
            guard let data = try? Data(contentsOf: entry) else { continue }
            for lineData in data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true) {
                guard let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      (object["ai_tool"] as? String) == "claude",
                      let runID = object["run_id"] as? String, !runID.isEmpty,
                      let spanID = object["span_id"] as? String, !spanID.isEmpty
                else { continue }
                result[runID, default: []].insert(spanID)
            }
        }
        return result
    }

    /// Moves staged event files into the live inbox so the collector drain imports them.
    /// `.accounting` sidecars are moved before their `.jsonl`/`.json` events so the inbox
    /// reader never sees an event without its accounting detail. Leftover `.tmp` files are
    /// discarded.
    ///
    /// - Returns: the run_ids whose canonical event file was moved successfully. Callers
    ///   must only reconcile (delete stale rows for) run_ids in this set — a run_id whose
    ///   move failed keeps its old (possibly duplicated) data untouched rather than losing
    ///   it outright, since we can no longer guarantee a replacement is on the way in.
    @discardableResult
    private func moveStagedInboxFilesToLiveInbox(from staging: URL) -> Set<String> {
        guard let liveInbox = store.eventsInboxURL,
              let entries = try? FileManager.default.contentsOfDirectory(
                at: staging,
                includingPropertiesForKeys: nil
              )
        else {
            return []
        }

        _ = try? TokenUsageStore.createPrivateDirectoryIfNeeded(at: liveInbox)
        let sidecars = entries.filter { $0.pathExtension == "accounting" }
        let events = entries.filter { $0.pathExtension == "json" || $0.pathExtension == "jsonl" }

        // Sidecar move failures are not tracked against run_id success below: losing
        // accounting detail only degrades measurement-quality data, not event integrity.
        for sidecar in sidecars {
            moveInboxFile(sidecar, to: liveInbox)
        }

        var movedRunIDs = Set<String>()
        for event in events {
            let runIDsInFile = claudeRunIDs(inEventFile: event)
            guard moveInboxFile(event, to: liveInbox) else { continue }
            movedRunIDs.formUnion(runIDsInFile)
        }

        try? FileManager.default.removeItem(at: staging)
        return movedRunIDs
    }

    @discardableResult
    private func moveInboxFile(_ source: URL, to liveInbox: URL) -> Bool {
        let destination = liveInbox.appendingPathComponent(source.lastPathComponent)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: source, to: destination)
            return true
        } catch {
            return false
        }
    }

    private func claudeRunIDs(inEventFile url: URL) -> Set<String> {
        guard let data = try? Data(contentsOf: url) else { return [] }
        var runIDs = Set<String>()
        for lineData in data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true) {
            guard let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  (object["ai_tool"] as? String) == "claude",
                  let runID = object["run_id"] as? String, !runID.isEmpty
            else { continue }
            runIDs.insert(runID)
        }
        return runIDs
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
