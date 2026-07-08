import Foundation

extension TokenUsageHistoryImportCoordinator {
    func syncClaudeHistoryStateToLiveState() {
        let fileManager = FileManager.default
        let historyStateDir = claudeHistorySessionStateDirectory()
        let liveStateDir = historyStateDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("session-state", isDirectory: true)

        guard let files = try? fileManager.contentsOfDirectory(
            at: historyStateDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for historyFile in files where historyFile.pathExtension == "json" {
            guard let historyData = try? Data(contentsOf: historyFile),
                  let historyState = try? JSONSerialization.jsonObject(with: historyData) as? [String: Any],
                  let historyFresh = historyState["fresh"] as? Int,
                  historyFresh > 0
            else { continue }

            let liveFile = liveStateDir.appendingPathComponent(historyFile.lastPathComponent)
            var liveFresh = 0
            if let liveData = try? Data(contentsOf: liveFile),
               let liveState = try? JSONSerialization.jsonObject(with: liveData) as? [String: Any],
               let currentFresh = liveState["fresh"] as? Int {
                liveFresh = currentFresh
            }

            guard historyFresh > liveFresh else { continue }

            let tmpFile = liveStateDir.appendingPathComponent(".\(historyFile.lastPathComponent).sync.tmp")
            _ = try? TokenUsageStore.createPrivateDirectoryIfNeeded(at: liveStateDir)
            guard (try? historyData.write(to: tmpFile)) != nil else { continue }
            do {
                if fileManager.fileExists(atPath: liveFile.path) {
                    _ = try fileManager.replaceItemAt(liveFile, withItemAt: tmpFile)
                } else {
                    try fileManager.moveItem(at: tmpFile, to: liveFile)
                }
            } catch {
                try? fileManager.removeItem(at: tmpFile)
            }
        }
    }

    // Keep the live AGY active importer aligned with explicit history sync.
    // Otherwise the next AGY turn can re-trigger a large catch-up import.
    func syncAntigravityHistoryStateToLiveState() {
        let historyStateFile = historyStateDirectory
            .appendingPathComponent("antigravity-active-importer-state.json")
        let liveStateFile = historyStateDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("session-state", isDirectory: true)
            .appendingPathComponent("antigravity-active-importer-state.json")

        guard let historyData = try? Data(contentsOf: historyStateFile),
              let mergedData = Self.mergedAntigravityStateData(
                historyData: historyData,
                liveData: try? Data(contentsOf: liveStateFile)
              )
        else { return }

        let fileManager = FileManager.default
        let liveStateDir = liveStateFile.deletingLastPathComponent()
        let tmpFile = liveStateDir.appendingPathComponent(".antigravity-active-importer-state.sync.tmp")
        _ = try? TokenUsageStore.createPrivateDirectoryIfNeeded(at: liveStateDir)
        try? fileManager.removeItem(at: tmpFile)
        guard (try? mergedData.write(to: tmpFile)) != nil else { return }
        try? fileManager.removeItem(at: liveStateFile)
        try? fileManager.moveItem(at: tmpFile, to: liveStateFile)
    }

    static func mergedAntigravityStateData(historyData: Data, liveData: Data?) -> Data? {
        let historyCursors = antigravityCursorMap(from: historyData)
        guard !historyCursors.isEmpty else {
            return nil
        }

        var mergedCursors = antigravityCursorMap(from: liveData)
        for (source, index) in historyCursors {
            mergedCursors[source] = max(mergedCursors[source] ?? -1, index)
        }

        let object: [String: Any] = [
            "schema_version": 1,
            "ai_tool": "antigravity",
            "privacy": "Contains only opaque conversation hashes and numeric generation cursors; no paths, prompts, responses, commands, logs, diffs, source, environment values, or secrets.",
            "max_generation_index_by_source": mergedCursors,
        ]
        return try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    static func antigravityCursorMap(from data: Data?) -> [String: Int] {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cursors = object["max_generation_index_by_source"] as? [String: Any]
        else {
            return [:]
        }

        var result = [String: Int]()
        for (source, value) in cursors {
            if let index = value as? Int {
                result[source] = index
            } else if let number = value as? NSNumber {
                result[source] = number.intValue
            }
        }
        return result
    }


    func prepareFullHistoryReconciliation(for tools: [TokenUsageHistoryImportTool]) throws {
        store.drainQueuedEventsWithoutLoading(maximumInboxEventCount: nil)
        resetToolScanState(for: tools)
        try TokenUsageStore.createPrivateDirectoryIfNeeded(at: historyStateDirectory)
    }

    func claudeHistorySessionStateDirectory() -> URL {
        historyStateDirectory.appendingPathComponent("claude-session-state", isDirectory: true)
    }


    func resetToolScanState(for tools: [TokenUsageHistoryImportTool]) {
        // Claude history scan state tracks per-transcript token totals. Without
        // clearing it, scan_main treats transcripts as already processed even
        // when --all is passed.
        if tools.contains(.claude) {
            let sessionStateDir = claudeHistorySessionStateDirectory()
            if let files = try? FileManager.default.contentsOfDirectory(
                at: sessionStateDir,
                includingPropertiesForKeys: nil
            ) {
                for file in files where file.pathExtension == "json" {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }

        // Codex and AGY each have a single state file in historyStateDirectory.
        if tools.contains(.codex) {
            let codexState = historyStateDirectory.appendingPathComponent("codex-session-import-state.json")
            try? FileManager.default.removeItem(at: codexState)
        }
        if tools.contains(.antigravity) {
            let antigravityState = historyStateDirectory.appendingPathComponent("antigravity-active-importer-state.json")
            try? FileManager.default.removeItem(at: antigravityState)
        }
    }

}
