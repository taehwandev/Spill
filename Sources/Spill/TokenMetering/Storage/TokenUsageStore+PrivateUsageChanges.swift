import Foundation
import SQLite3

struct PrivateUsageEventChange: Equatable, Sendable {
    let changeID: Int64
    let eventCreatedAt: String
}

extension TokenUsageStore {
    func loadPrivateUsageFullResyncCheckpoint() -> PrivateUsageFullResyncCheckpoint {
        lock.withLock {
            guard let database = try? openDatabase() else {
                return PrivateUsageFullResyncCheckpoint(eventCreatedAts: [], maxChangeID: 0)
            }
            defer { sqlite3_close(database) }

            var createdAts = [String]()
            var eventStatement: OpaquePointer?
            if sqlite3_prepare_v2(
                database,
                "SELECT created_at FROM token_usage_events ORDER BY created_at ASC",
                -1,
                &eventStatement,
                nil
            ) == SQLITE_OK,
               let eventStatement
            {
                defer { sqlite3_finalize(eventStatement) }
                while sqlite3_step(eventStatement) == SQLITE_ROW {
                    if let bytes = sqlite3_column_text(eventStatement, 0) {
                        createdAts.append(String(cString: bytes))
                    }
                }
            }

            var maxChangeID: Int64 = 0
            var changeStatement: OpaquePointer?
            if sqlite3_prepare_v2(
                database,
                "SELECT COALESCE(MAX(change_id), 0) FROM private_usage_event_changes",
                -1,
                &changeStatement,
                nil
            ) == SQLITE_OK,
               let changeStatement
            {
                defer { sqlite3_finalize(changeStatement) }
                if sqlite3_step(changeStatement) == SQLITE_ROW {
                    maxChangeID = sqlite3_column_int64(changeStatement, 0)
                }
            }

            return PrivateUsageFullResyncCheckpoint(
                eventCreatedAts: createdAts,
                maxChangeID: maxChangeID
            )
        }
    }

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

    func prunePrivateUsageEventChanges(throughChangeID changeID: Int64) {
        guard changeID > 0 else {
            return
        }

        lock.withLock {
            guard let database = try? openDatabase() else {
                return
            }
            defer { sqlite3_close(database) }

            let sql = "DELETE FROM private_usage_event_changes WHERE change_id <= ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                return
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, changeID)
            _ = sqlite3_step(statement)
        }
    }
}
