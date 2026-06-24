import Foundation
import SQLite3

extension TokenUsageStore {
    func clearEvents() throws {
        try lock.withLock {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try execute("DELETE FROM token_usage_events", database: database)
            try removeLegacyEventsFileWithoutLock()
            if let inboxURL, FileManager.default.fileExists(atPath: inboxURL.path) {
                try FileManager.default.removeItem(at: inboxURL)
            }
            if let inboxURL {
                let legacyInboxURL = inboxURL
                    .deletingLastPathComponent()
                    .appendingPathComponent("events-inbox.jsonl")
                if FileManager.default.fileExists(atPath: legacyInboxURL.path) {
                    try FileManager.default.removeItem(at: legacyInboxURL)
                }
            }
        }
        resetImporterState(for: TokenUsageAITool.allCases)
        postEventsDidChange()
    }

    func clearEvents(forAITool aiTool: String) throws {
        try lock.withLock {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, "DELETE FROM token_usage_events WHERE ai_tool = ?", -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                throw TokenUsageStoreError.databaseWriteFailed
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, aiTool, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw TokenUsageStoreError.databaseWriteFailed
            }
        }
        if let tool = TokenUsageAITool(rawValue: aiTool) {
            resetImporterState(for: [tool])
        }
        postEventsDidChange()
    }

    func clearEvents(for aiTools: [TokenUsageAITool]) throws {
        let toolValues = aiTools.map(\.rawValue)
        guard !toolValues.isEmpty else {
            return
        }

        try lock.withLock {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            _ = try migrateLegacyJSONEventsIfNeeded(database: database)

            let placeholders = Array(repeating: "?", count: toolValues.count).joined(separator: ", ")
            let sql = "DELETE FROM token_usage_events WHERE ai_tool IN (\(placeholders))"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                throw TokenUsageStoreError.databaseWriteFailed
            }
            defer { sqlite3_finalize(statement) }

            for (index, toolValue) in toolValues.enumerated() {
                sqlite3_bind_text(statement, Int32(index + 1), toolValue, -1, SQLITE_TRANSIENT)
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw TokenUsageStoreError.databaseWriteFailed
            }
            try removeLegacyEventsFileWithoutLock()
        }
        resetImporterState(for: aiTools)
        postEventsDidChange()
    }


    func notifyEventsDidChange() {
        postEventsDidChange()
    }

    func postEventsDidChange() {
        NotificationCenter.default.post(
            name: Self.eventsDidChangeNotification,
            object: self
        )
        DistributedNotificationCenter.default().postNotificationName(
            Self.distributedEventsDidChangeNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    func resetImporterState(for aiTools: [TokenUsageAITool]) {
        let fileManager = FileManager.default
        let tokenMeteringDir = tokenMeteringDirectory
        let sessionStateDir = tokenMeteringDir.appendingPathComponent("session-state", isDirectory: true)
        let historyImportDir = tokenMeteringDir.appendingPathComponent("history-import", isDirectory: true)

        for tool in aiTools {
            switch tool {
            case .antigravity:
                let activeState = sessionStateDir.appendingPathComponent("antigravity-active-importer-state.json")
                let historyState = historyImportDir.appendingPathComponent("antigravity-active-importer-state.json")
                try? fileManager.removeItem(at: activeState)
                try? fileManager.removeItem(at: historyState)
            case .codex:
                // History import state
                let codexHistoryState = historyImportDir.appendingPathComponent("codex-session-import-state.json")
                try? fileManager.removeItem(at: codexHistoryState)
                // Live Stop-hook state (default path used by the live importer)
                let codexLiveState = tokenMeteringDir.appendingPathComponent("codex-session-import-state.json")
                try? fileManager.removeItem(at: codexLiveState)
            case .claude:
                let claudeDir = historyImportDir.appendingPathComponent("claude-session-state", isDirectory: true)
                if let files = try? fileManager.contentsOfDirectory(at: claudeDir, includingPropertiesForKeys: nil) {
                    for file in files where file.pathExtension == "json" {
                        try? fileManager.removeItem(at: file)
                    }
                }
            default:
                break
            }
        }
    }
}
