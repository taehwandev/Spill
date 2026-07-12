import Foundation
import SQLite3

struct PrivateUsageEventChange: Equatable, Sendable {
    let changeID: Int64
    let eventCreatedAt: String
}

extension TokenUsageStore {
    func loadPrivateUsageEventChanges(
        afterChangeID changeID: Int64
    ) -> (changes: [PrivateUsageEventChange], maxChangeID: Int64) {
        lock.withLock {
            guard let database = try? openDatabase() else {
                return ([], changeID)
            }
            defer { sqlite3_close(database) }

            let sql = """
            SELECT change_id, event_created_at
            FROM private_usage_event_changes
            WHERE change_id > ?
            ORDER BY change_id ASC
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                return ([], changeID)
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, changeID)

            var changes = [PrivateUsageEventChange]()
            var maxChangeID = changeID
            while sqlite3_step(statement) == SQLITE_ROW {
                let currentChangeID = sqlite3_column_int64(statement, 0)
                guard let createdAtBytes = sqlite3_column_text(statement, 1) else {
                    continue
                }
                changes.append(
                    PrivateUsageEventChange(
                        changeID: currentChangeID,
                        eventCreatedAt: String(cString: createdAtBytes)
                    )
                )
                maxChangeID = max(maxChangeID, currentChangeID)
            }
            return (changes, maxChangeID)
        }
    }
}
