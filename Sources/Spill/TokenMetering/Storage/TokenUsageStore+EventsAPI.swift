import Foundation
import SQLite3

extension TokenUsageStore {
    func loadEvents() -> [TokenUsageEvent] {
        lock.withLock {
            readEventsWithoutLock()
        }
    }

    func loadEvents(
        startingAt startDate: Date?,
        endingBefore endDate: Date?
    ) -> [TokenUsageEvent] {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return []
            }
            defer { sqlite3_close(database) }

            return loadDatabaseEvents(
                startingAt: startDate,
                endingBefore: endDate,
                database: database
            )
        }
    }

    @discardableResult

    func replaceEvents(_ events: [TokenUsageEvent]) throws -> [TokenUsageEvent] {
        let replacedEvents = try lock.withLock {
            for event in events {
                try event.validate()
            }

            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try replaceDatabaseEvents(events, database: database)
            try removeLegacyEventsFileWithoutLock()
            return loadDatabaseEvents(database: database)
        }

        postEventsDidChange()
        return replacedEvents
    }

    @discardableResult
    func appendEvent(_ event: TokenUsageEvent) throws -> [TokenUsageEvent] {
        let nextEvents = try lock.withLock {
            try event.validate()
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            _ = try migrateLegacyJSONEventsIfNeeded(database: database)
            _ = try insertEvent(event, database: database)
            return loadDatabaseEvents(database: database)
        }

        postEventsDidChange()
        return nextEvents
    }

    @discardableResult
    func appendEventsWithoutLoading(_ events: [TokenUsageEvent]) throws -> Int {
        guard !events.isEmpty else {
            return 0
        }

        let insertedCount = try lock.withLock {
            for event in events {
                try event.validate()
            }

            let database = try openDatabase()
            defer { sqlite3_close(database) }
            _ = try migrateLegacyJSONEventsIfNeeded(database: database)
            return try insertEvents(events, database: database)
        }

        if insertedCount > 0 {
            postEventsDidChange()
        }
        return insertedCount
    }

    func loadEvents(afterRowID rowID: Int64) -> (events: [TokenUsageEvent], maxRowID: Int64) {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return ([], rowID)
            }
            defer { sqlite3_close(database) }

            return loadDatabaseEventsAfterRowID(rowID, database: database)
        }
    }

    func currentEventCount() -> Int {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return 0
            }
            defer { sqlite3_close(database) }

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM token_usage_events", -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                return 0
            }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }
            return Int(sqlite3_column_int64(statement, 0))
        }
    }


    func envelopeData() throws -> Data {
        try TokenUsageSanitizer.envelopeData(events: loadEvents())
    }

}
