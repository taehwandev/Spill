import Foundation

extension TokenUsageClaudeCodeImporter {
    /// Records the last active-importer pass so a machine whose Claude usage
    /// stops updating can be diagnosed from local files alone.
    func writeDiagnostic(_ summary: TokenUsageClaudeCodeImportSummary) {
        guard let diagnosticsURL else {
            return
        }

        var isDirectory: ObjCBool = false
        let projectsDirectoryFound = fileManager.fileExists(
            atPath: projectsDirectory.path,
            isDirectory: &isDirectory
        ) && isDirectory.boolValue

        let object: [String: Any] = [
            "schema_version": 1,
            "ai_tool": "claude",
            "kind": "active_importer_scan",
            "created_at": ISO8601DateFormatter.tokenUsage.string(from: now()),
            "projects_directory_found": projectsDirectoryFound,
            "scanned_session_files": summary.scannedFiles,
            "parsed_turns": summary.parsedTurns,
            "imported_events": summary.importedEvents,
            "skipped_duplicate_events": summary.skippedDuplicateEvents,
            "invalid_events": summary.invalidEvents,
            "cursor_advanced_files": summary.cursorAdvancedFiles,
            "failed_to_write_events": summary.failedToWriteEvents,
            "privacy": "No payload values, prompts, responses, commands, file paths, logs, diffs, source, environment values, or secrets are stored."
        ]

        do {
            try fileManager.createDirectory(
                at: diagnosticsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            try data.write(to: diagnosticsURL, options: [.atomic])
        } catch {
            return
        }
    }
}
