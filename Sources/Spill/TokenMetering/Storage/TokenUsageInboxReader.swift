import Foundation

struct TokenUsageInboxReader {
    let inboxURL: URL?
}

extension TokenUsageInboxReader {
    func load(maximumEventCount: Int?) -> TokenUsageInboxReader.ReadResult {
        var events = [TokenUsageEvent]()
        var consumedURLs = [URL]()
        var deferredJSONLFiles = [TokenUsageInboxReader.DeferredJSONLFile]()
        let maximumEventCount = maximumEventCount.map { max(0, $0) }

        if let inboxURL,
           let urls = try? FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
           ) {
            let inboxEventURLs = urls
                .filter(isInboxEventFile)
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

            for url in inboxEventURLs {
                if let maximumEventCount, events.count >= maximumEventCount {
                    break
                }

                if url.pathExtension == "jsonl" {
                    let remainingEventCount = maximumEventCount.map { max(0, $0 - events.count) }
                    guard remainingEventCount != 0 else {
                        break
                    }

                    if let jsonlResult = loadJSONLInboxEvents(from: url, maximumEventCount: remainingEventCount) {
                        events.append(contentsOf: jsonlResult.events)
                        if let remainingContents = jsonlResult.remainingContents {
                            deferredJSONLFiles.append(
                                TokenUsageInboxReader.DeferredJSONLFile(
                                    finalURL: deferredJSONLInboxURL(for: url),
                                    contents: remainingContents
                                )
                            )
                        }
                        consumedURLs.append(url)
                        if jsonlResult.remainingContents != nil {
                            break
                        }
                    }
                } else if let event = loadInboxEvent(from: url) {
                    if let maximumEventCount, events.count >= maximumEventCount {
                        break
                    }
                    events.append(event)
                    consumedURLs.append(url)
                } else {
                    consumedURLs.append(url)
                }
            }
        }

        if let maximumEventCount, events.count >= maximumEventCount {
            return TokenUsageInboxReader.ReadResult(
                events: events,
                consumedURLs: consumedURLs,
                deferredJSONLFiles: deferredJSONLFiles
            )
        }

        if let legacyInboxURL = legacyJSONLInboxURL(),
           let legacyResult = loadJSONLInboxEvents(
            from: legacyInboxURL,
            maximumEventCount: maximumEventCount.map { max(0, $0 - events.count) }
           ) {
            events.append(contentsOf: legacyResult.events)
            consumedURLs.append(legacyInboxURL)
            if let remainingContents = legacyResult.remainingContents {
                deferredJSONLFiles.append(
                    TokenUsageInboxReader.DeferredJSONLFile(
                        finalURL: deferredJSONLInboxURL(for: legacyInboxURL),
                        contents: remainingContents
                    )
                )
            }
        }

        return TokenUsageInboxReader.ReadResult(
            events: events,
            consumedURLs: consumedURLs,
            deferredJSONLFiles: deferredJSONLFiles
        )
    }
}

private extension TokenUsageInboxReader {
    private func isInboxEventFile(_ url: URL) -> Bool {
        url.pathExtension == "json" || url.pathExtension == "jsonl"
    }

    private func loadInboxEvent(from url: URL) -> TokenUsageEvent? {
        guard let data = try? Data(contentsOf: url),
              let event = try? TokenUsageSanitizer.sanitizeEventJSONData(data)
        else {
            return nil
        }

        return event
    }

    private func loadJSONLInboxEvents(
        from url: URL,
        maximumEventCount: Int? = nil
    ) -> JSONLReadResult? {
        guard let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        var events = [TokenUsageEvent]()
        var remainingLines = [String]()
        let maximumEventCount = maximumEventCount.map { max(0, $0) }

        for line in contents.split(whereSeparator: \.isNewline) {
            if let maximumEventCount, events.count >= maximumEventCount {
                remainingLines.append(String(line))
                continue
            }

            let event = String(line).data(using: .utf8).flatMap { data -> TokenUsageEvent? in
                try? TokenUsageSanitizer.sanitizeEventJSONData(data)
            }
            if let event {
                events.append(event)
            }
        }

        let remainingContents: String?
        if remainingLines.isEmpty {
            remainingContents = nil
        } else {
            remainingContents = remainingLines.joined(separator: "\n") + "\n"
        }

        return JSONLReadResult(events: events, remainingContents: remainingContents)
    }

    private func deferredJSONLInboxURL(for consumedURL: URL) -> URL {
        consumedURL
    }

    private func legacyJSONLInboxURL() -> URL? {
        guard let inboxURL else {
            return nil
        }

        return inboxURL
            .deletingLastPathComponent()
            .appendingPathComponent("events-inbox.jsonl")
    }
}

extension TokenUsageInboxReader {
    struct ReadResult {
        let events: [TokenUsageEvent]
        let consumedURLs: [URL]
        let deferredJSONLFiles: [DeferredJSONLFile]
    }

    struct DeferredJSONLFile {
        let finalURL: URL
        let contents: String
    }
}

private extension TokenUsageInboxReader {
    struct JSONLReadResult {
        let events: [TokenUsageEvent]
        let remainingContents: String?
    }
}
