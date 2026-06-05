import Foundation

final class TokenUsageStore: @unchecked Sendable {
    static let eventsDidChangeNotification = Notification.Name("app.spill.token-usage-store.events-did-change")

    private let fileURL: URL
    private let inboxURL: URL?
    private let lock = NSLock()

    init(
        fileURL: URL = TokenUsageStore.defaultEventsURL(),
        inboxURL: URL? = nil
    ) {
        self.fileURL = fileURL
        self.inboxURL = inboxURL
    }

    var eventsFileURL: URL {
        fileURL
    }

    var eventsInboxURL: URL? {
        inboxURL
    }

    func loadEvents() -> [TokenUsageEvent] {
        lock.withLock {
            loadEventsWithoutLock().events
        }
    }

    @discardableResult
    func importQueuedEvents() -> [TokenUsageEvent] {
        let result = lock.withLock {
            loadEventsWithoutLock()
        }

        if result.didImportQueuedEvents {
            postEventsDidChange()
        }

        return result.events
    }

    @discardableResult
    func replaceEvents(_ events: [TokenUsageEvent]) throws -> [TokenUsageEvent] {
        let replacedEvents = try lock.withLock {
            for event in events {
                try event.validate()
            }

            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try TokenUsageSanitizer.jsonEncoder.encode(events)
            try data.write(to: fileURL, options: [.atomic])
            return events
        }

        postEventsDidChange()
        return replacedEvents
    }

    @discardableResult
    func appendEvent(_ event: TokenUsageEvent) throws -> [TokenUsageEvent] {
        let nextEvents = try lock.withLock {
            try event.validate()
            let currentEvents = loadEventsWithoutLock().events
            let nextEvents = currentEvents + [event]

            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try TokenUsageSanitizer.jsonEncoder.encode(nextEvents)
            try data.write(to: fileURL, options: [.atomic])
            return nextEvents
        }

        postEventsDidChange()
        return nextEvents
    }

    func clearEvents() throws {
        try lock.withLock {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            if let inboxURL, FileManager.default.fileExists(atPath: inboxURL.path) {
                try FileManager.default.removeItem(at: inboxURL)
            }
            if let legacyInboxURL = legacyJSONLInboxURL(),
               FileManager.default.fileExists(atPath: legacyInboxURL.path) {
                try FileManager.default.removeItem(at: legacyInboxURL)
            }
        }

        postEventsDidChange()
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

        postEventsDidChange()
    }

    func envelopeData() throws -> Data {
        try TokenUsageSanitizer.envelopeData(events: loadEvents())
    }

    static func defaultEventsURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("Spill", isDirectory: true)
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("events.json")
    }

    static func defaultInboxURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("Spill", isDirectory: true)
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("events-inbox", isDirectory: true)
    }

    static func live() -> TokenUsageStore {
        TokenUsageStore(
            fileURL: defaultEventsURL(),
            inboxURL: defaultInboxURL()
        )
    }

    private func loadEventsWithoutLock() -> StoreLoadResult {
        let inboxResult = loadInboxEvents()
        let events = deduplicatedEvents(loadJSONEvents(from: fileURL) + inboxResult.events)

        if !inboxResult.consumedURLs.isEmpty {
            try? persistEventsWithoutLock(events)
            removeConsumedInboxFiles(inboxResult.consumedURLs)
        }

        return StoreLoadResult(
            events: events,
            didImportQueuedEvents: !inboxResult.consumedURLs.isEmpty
        )
    }

    private func loadJSONEvents(from url: URL) -> [TokenUsageEvent] {
        guard let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([TokenUsageEvent].self, from: data)
        else {
            return []
        }

        return events.filter { event in
            do {
                try event.validate()
                return true
            } catch {
                return false
            }
        }
    }

    private func loadInboxEvents() -> InboxReadResult {
        var events = [TokenUsageEvent]()
        var consumedURLs = [URL]()

        if let inboxURL,
           let urls = try? FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
           ) {
            for url in urls
                .filter({ $0.pathExtension == "json" })
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if let event = loadInboxEvent(from: url) {
                    events.append(event)
                }
                consumedURLs.append(url)
            }
        }

        if let legacyInboxURL = legacyJSONLInboxURL(),
           let legacyEvents = loadLegacyJSONLInboxEvents(from: legacyInboxURL) {
            events.append(contentsOf: legacyEvents)
            consumedURLs.append(legacyInboxURL)
        }

        return InboxReadResult(events: events, consumedURLs: consumedURLs)
    }

    private func loadInboxEvent(from url: URL) -> TokenUsageEvent? {
        guard let data = try? Data(contentsOf: url),
              let event = try? TokenUsageSanitizer.sanitizeEventJSONData(data)
        else {
            return nil
        }

        return event
    }

    private func loadLegacyJSONLInboxEvents(from url: URL) -> [TokenUsageEvent]? {
        guard let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return contents
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> TokenUsageEvent? in
                guard let data = String(line).data(using: .utf8) else {
                    return nil
                }

                return try? TokenUsageSanitizer.sanitizeEventJSONData(data)
            }
    }

    private func persistEventsWithoutLock(_ events: [TokenUsageEvent]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try TokenUsageSanitizer.jsonEncoder.encode(events)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func removeConsumedInboxFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func legacyJSONLInboxURL() -> URL? {
        guard let inboxURL else {
            return nil
        }

        return inboxURL
            .deletingLastPathComponent()
            .appendingPathComponent("events-inbox.jsonl")
    }

    private func deduplicatedEvents(_ events: [TokenUsageEvent]) -> [TokenUsageEvent] {
        var seenSpanIDs = Set<String>()
        return events.filter { event in
            seenSpanIDs.insert(event.spanID).inserted
        }
    }

    private func postEventsDidChange() {
        NotificationCenter.default.post(
            name: Self.eventsDidChangeNotification,
            object: self
        )
    }
}

private struct InboxReadResult {
    let events: [TokenUsageEvent]
    let consumedURLs: [URL]
}

private struct StoreLoadResult {
    let events: [TokenUsageEvent]
    let didImportQueuedEvents: Bool
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
