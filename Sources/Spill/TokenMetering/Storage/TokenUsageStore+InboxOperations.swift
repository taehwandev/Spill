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
            let accountingTemporaryURL = inboxURL.appendingPathComponent(".\(eventID).accounting.tmp")
            let accountingFinalURL = inboxURL.appendingPathComponent("\(eventID).accounting")
            let data = try TokenUsageSanitizer.eventData(event)

            try data.write(to: temporaryURL, options: [.withoutOverwriting])
            if let accounting = event.tokenAccounting {
                let accountingRecord = accountingSidecarRecord(for: event, accounting: accounting)
                try Data((accountingRecord + "\n").utf8).write(
                    to: accountingTemporaryURL,
                    options: [.withoutOverwriting]
                )
            }
            if FileManager.default.fileExists(atPath: accountingTemporaryURL.path) {
                try FileManager.default.moveItem(at: accountingTemporaryURL, to: accountingFinalURL)
            }
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
                let events = inboxResult.events.map { event in
                    event.withTokenAccounting(inboxResult.accountingBySpanID[event.spanID] ?? event.tokenAccounting)
                }
                let insertedEventCount = try insertEvents(events, database: database)
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

    private func accountingSidecarRecord(for event: TokenUsageEvent, accounting: TokenUsageAccounting) -> String {
        let record: [String: Any] = [
            "schema_version": 1,
            "span_id": event.spanID,
            "ai_tool": event.aiTool.rawValue,
            "uncached_input_tokens": accounting.uncachedInputTokens,
            "cache_creation_input_tokens": accounting.cacheCreationInputTokens,
            "cache_read_input_tokens": accounting.cacheReadInputTokens,
            "reasoning_output_tokens": accounting.reasoningOutputTokens
        ]
        let data = (try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }

}
