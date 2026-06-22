import Foundation

extension TokenUsageAntigravityImporter {
    func writeDiagnostic(_ summary: TokenUsageAntigravityImportSummary) {
        guard let diagnosticsURL else {
            return
        }

        let object: [String: Any] = [
            "schema_version": 1,
            "ai_tool": "antigravity",
            "kind": "active_importer_scan",
            "created_at": ISO8601DateFormatter.tokenUsage.string(from: Date()),
            "scanned_databases": summary.scannedDatabases,
            "scanned_generation_rows": summary.scannedGenerationRows,
            "parsed_usage_events": summary.parsedUsageEvents,
            "imported_events": summary.importedEvents,
            "skipped_duplicate_events": summary.skippedDuplicateEvents,
            "unsupported_records": summary.unsupportedRecords,
            "split_output_fallback_events": summary.splitOutputFallbackEvents,
            "cursor_advanced_databases": summary.cursorAdvancedDatabases,
            "failed_to_write_events": summary.failedToWriteEvents,
            "timestamp_source": "generation_metadata_timestamp",
            "timestamp_limitation": "AGY gen_metadata rows without trusted numeric timestamps are counted as unsupported.",
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
