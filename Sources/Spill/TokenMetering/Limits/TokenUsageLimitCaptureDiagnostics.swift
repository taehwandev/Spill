import Foundation

/// Content-free local record of what a limit capture pass found.
///
/// An exact source can vanish under Spill without any visible failure: the
/// client renames or drops the state it used to cache, the capture reads
/// nothing, and the estimated gauges quietly take over wearing a `~`. That is
/// exactly what happened to Claude's cached utilization, and nothing recorded
/// it. This file makes the difference between "no exact reading exists" and
/// "the reading moved" answerable without inspecting anything private.
///
/// Privacy: only fixed booleans, counts, and timestamps are stored. No paths,
/// keys, prompts, responses, commands, logs, transcripts, model ids, or any
/// value read out of the inspected file is written here.
struct TokenUsageLimitCaptureDiagnostics {
    struct Record {
        let stateFileFound: Bool
        let stateFileParsed: Bool
        let utilizationFound: Bool
        /// True when the payload was located by structural scan rather than
        /// under the key the client used to use — the early warning that the
        /// vendor moved its state again.
        let foundByStructuralScan: Bool
        let limitEntryCount: Int
        let windowedLimitCount: Int
    }

    let fileURL: URL?
    let fileManager: FileManager
    let now: () -> Date

    init(
        fileURL: URL? = TokenUsageLimitCaptureDiagnostics.defaultClaudeFileURL(),
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.now = now
    }

    static func defaultClaudeFileURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("diagnostics", isDirectory: true)
            .appendingPathComponent("claude-limit-capture-last.json")
    }

    func write(_ record: Record) {
        guard let fileURL else {
            return
        }
        let object: [String: Any] = [
            "schema_version": 1,
            "ai_tool": "claude",
            "kind": "limit_capture_scan",
            "created_at": ISO8601DateFormatter.tokenUsage.string(from: now()),
            "state_file_found": record.stateFileFound,
            "state_file_parsed": record.stateFileParsed,
            "utilization_found": record.utilizationFound,
            "found_by_structural_scan": record.foundByStructuralScan,
            "limit_entry_count": record.limitEntryCount,
            "windowed_limit_count": record.windowedLimitCount,
            "privacy": "Only fixed booleans, counts, and timestamps are stored. No paths, keys, prompts, responses, commands, logs, diffs, source, environment values, or secrets."
        ]
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            return
        }
    }
}
