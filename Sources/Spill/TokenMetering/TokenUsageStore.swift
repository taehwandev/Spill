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
            loadEventsWithoutLock()
        }
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
            let currentEvents = loadEventsWithoutLock()
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
            .appendingPathComponent("events-inbox.jsonl")
    }

    static func live() -> TokenUsageStore {
        TokenUsageStore(
            fileURL: defaultEventsURL(),
            inboxURL: defaultInboxURL()
        )
    }

    private func loadEventsWithoutLock() -> [TokenUsageEvent] {
        deduplicatedEvents(loadJSONEvents(from: fileURL) + loadInboxEvents())
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

    private func loadInboxEvents() -> [TokenUsageEvent] {
        guard let inboxURL,
              let data = try? Data(contentsOf: inboxURL),
              let contents = String(data: data, encoding: .utf8)
        else {
            return []
        }

        return contents
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> TokenUsageEvent? in
                guard let data = String(line).data(using: .utf8),
                      let event = try? JSONDecoder().decode(TokenUsageEvent.self, from: data)
                else {
                    return nil
                }

                do {
                    try event.validate()
                    return event
                } catch {
                    return nil
                }
            }
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

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
