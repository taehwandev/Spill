import Foundation
import SQLite3

extension TokenUsageStore {
    func importQueuedEvents() -> [TokenUsageEvent] {
        let inboxResult = TokenUsageInboxReader(inboxURL: inboxURL)
            .load(maximumEventCount: nil)
        let result = lock.withLock {
            importQueuedEventsWithoutLock(loadEvents: true, inboxResult: inboxResult)
        }

        if result.didImportQueuedEvents {
            postEventsDidChange()
        }

        return result.events
    }

    @discardableResult
    func importQueuedEventsWithoutLoading(
        maximumInboxEventCount: Int? = 500
    ) -> Bool {
        let inboxResult = TokenUsageInboxReader(inboxURL: inboxURL)
            .load(maximumEventCount: maximumInboxEventCount)
        let didImportQueuedEvents = lock.withLock {
            importQueuedEventsWithoutLock(loadEvents: false, inboxResult: inboxResult).didImportQueuedEvents
        }

        if didImportQueuedEvents {
            postEventsDidChange()
        }

        return didImportQueuedEvents
    }

    @discardableResult
    func drainQueuedEventsWithoutLoading(
        maximumInboxEventCount: Int? = TokenUsageStore.defaultInboxImportBatchLimit,
        maximumBatchCount: Int = TokenUsageStore.defaultInboxDrainBatchCount,
        scheduleFollowUpDrain: (() -> Void)? = nil
    ) -> Bool {
        var didImportQueuedEvents = false
        var didConsumeQueuedFiles = false
        let batchLimit = max(1, maximumBatchCount)
        var processedBatchCount = 0

        while processedBatchCount < batchLimit {
            let inboxResult = TokenUsageInboxReader(inboxURL: inboxURL)
                .load(maximumEventCount: maximumInboxEventCount)
            guard !inboxResult.consumedURLs.isEmpty else {
                break
            }

            processedBatchCount += 1
            let didImportBatch = lock.withLock {
                importQueuedEventsWithoutLock(loadEvents: false, inboxResult: inboxResult).didImportQueuedEvents
            }
            didConsumeQueuedFiles = true
            didImportQueuedEvents = didImportQueuedEvents || didImportBatch

            if maximumInboxEventCount == nil {
                break
            }
        }

        if didImportQueuedEvents {
            postEventsDidChange()
        }

        if didConsumeQueuedFiles,
           maximumInboxEventCount != nil,
           processedBatchCount >= batchLimit,
           TokenUsageInboxReader(inboxURL: inboxURL).hasQueuedInboxFiles() {
            scheduleFollowUpDrain?()
        }

        return didImportQueuedEvents
    }

    func enqueueInboxEvent(_ event: TokenUsageEvent) throws {
        let inboxURL = inboxURL ?? Self.defaultInboxURL()

        try lock.withLock {
            try event.validate()
            try FileManager.default.createDirectory(
                at: inboxURL,
                withIntermediateDirectories: true
            )

            let eventID = UUID().uuidString.lowercased()
            let temporaryURL = inboxURL.appendingPathComponent(".\(eventID).tmp")
            let finalURL = inboxURL.appendingPathComponent("\(eventID).json")
            let data = try TokenUsageSanitizer.eventData(event)

            try data.write(to: temporaryURL, options: [.withoutOverwriting])
            try FileManager.default.moveItem(at: temporaryURL, to: finalURL)
        }
    }


    func importQueuedEventsWithoutLock(
        loadEvents: Bool,
        inboxResult: TokenUsageInboxReader.ReadResult
    ) -> StoreLoadResult {
        let database: OpaquePointer
        do {
            database = try openDatabase()
        } catch {
            return StoreLoadResult(events: [], didImportQueuedEvents: false)
        }
        defer { sqlite3_close(database) }

        let didMigrateLegacyEvents = (try? migrateLegacyJSONEventsIfNeeded(database: database)) ?? false
        var didImportQueuedEvents = didMigrateLegacyEvents

        if !inboxResult.consumedURLs.isEmpty {
            do {
                let insertedEventCount = try insertEvents(inboxResult.events, database: database)
                try TokenUsageInboxReader(inboxURL: inboxURL).commit(inboxResult)
                didImportQueuedEvents = didImportQueuedEvents || insertedEventCount > 0
            } catch {
                didImportQueuedEvents = false
            }
        }

        return StoreLoadResult(
            events: loadEvents ? loadDatabaseEvents(database: database) : [],
            didImportQueuedEvents: didImportQueuedEvents
        )
    }

}
