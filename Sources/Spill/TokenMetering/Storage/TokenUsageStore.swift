import Foundation
import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class TokenUsageStore: @unchecked Sendable {
    static let eventsDidChangeNotification = Notification.Name("app.spill.token-usage-store.events-did-change")
    static let distributedEventsDidChangeNotification = Notification.Name("app.spill.token-usage-store.events-did-change.distributed")
    static let defaultInboxImportBatchLimit = 500
    static let defaultInboxDrainBatchCount = 4
    static let eventSelectColumns = """
    span_id,
    device_id,
    project_id,
    artifact_id,
    run_id,
    created_at,
    ai_tool,
    task_type,
    stage,
    model,
    input_tokens,
    output_tokens,
    total_tokens,
    latency_ms,
    source_system,
    source_user,
    source_history,
    source_repo_context,
    source_tool_output,
    source_generated_output,
    source_unknown
    """

    let fileURL: URL
    let databaseURL: URL
    let inboxURL: URL?
    let lock = NSLock()
    var preparedDatabaseSchemaCheckpoint: DatabaseSchemaCheckpoint?

    init(
        fileURL: URL = TokenUsageStore.defaultEventsURL(),
        inboxURL: URL? = nil
    ) {
        self.fileURL = fileURL
        self.databaseURL = Self.defaultDatabaseURL(for: fileURL)
        self.inboxURL = inboxURL
    }

    var eventsFileURL: URL {
        fileURL
    }

    var eventsDatabaseURL: URL {
        databaseURL
    }

    var eventsInboxURL: URL? {
        inboxURL
    }

    var tokenMeteringDirectory: URL {
        fileURL.deletingLastPathComponent()
    }

}
