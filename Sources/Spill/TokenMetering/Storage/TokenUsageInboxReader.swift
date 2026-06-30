import Foundation

struct TokenUsageInboxReader {
    let inboxURL: URL?
}

extension TokenUsageInboxReader {
    func load(maximumEventCount: Int?) -> TokenUsageInboxReader.ReadResult {
        var events = [TokenUsageEvent]()
        var accountingBySpanID = [String: TokenUsageAccounting]()
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
                        accountingBySpanID.merge(loadAccountingMap(for: url)) { current, _ in current }
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
                    accountingBySpanID.merge(loadAccountingMap(for: url)) { current, _ in current }
                    consumedURLs.append(url)
                } else {
                    consumedURLs.append(url)
                }
            }
        }

        if let maximumEventCount, events.count >= maximumEventCount {
            return TokenUsageInboxReader.ReadResult(
                events: events,
                accountingBySpanID: accountingBySpanID,
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
            accountingBySpanID: accountingBySpanID,
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

    private func accountingInboxURL(for eventURL: URL) -> URL {
        eventURL.deletingPathExtension().appendingPathExtension("accounting")
    }

    private func loadAccountingMap(for eventURL: URL) -> [String: TokenUsageAccounting] {
        let url = accountingInboxURL(for: eventURL)
        guard let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8)
        else {
            return [:]
        }

        var result = [String: TokenUsageAccounting]()
        let lines = contents.split(whereSeparator: \.isNewline)
        if lines.isEmpty {
            return [:]
        }

        for line in lines {
            guard let record = loadAccountingRecord(from: Data(String(line).utf8)) else {
                continue
            }
            result[record.spanID] = record.accounting
        }
        return result
    }

    private func loadAccountingRecord(from data: Data) -> AccountingRecord? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              AccountingRecord.hasOnlyAllowedKeys(object)
        else {
            return nil
        }

        return try? JSONDecoder().decode(AccountingRecord.self, from: data)
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
        let accountingBySpanID: [String: TokenUsageAccounting]
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

    struct AccountingRecord: Codable {
        let schemaVersion: Int
        let spanID: String
        let aiTool: TokenUsageAITool?
        let accounting: TokenUsageAccounting

        enum CodingKeys: String, CodingKey, CaseIterable {
            case schemaVersion = "schema_version"
            case spanID = "span_id"
            case aiTool = "ai_tool"
            case uncachedInputTokens = "uncached_input_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case reasoningOutputTokens = "reasoning_output_tokens"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            spanID = try container.decode(String.self, forKey: .spanID)
            aiTool = try container.decodeIfPresent(TokenUsageAITool.self, forKey: .aiTool)
            accounting = TokenUsageAccounting(
                uncachedInputTokens: try container.decode(Int.self, forKey: .uncachedInputTokens),
                cacheCreationInputTokens: try container.decodeIfPresent(
                    Int.self,
                    forKey: .cacheCreationInputTokens
                ) ?? 0,
                cacheReadInputTokens: try container.decodeIfPresent(Int.self, forKey: .cacheReadInputTokens) ?? 0,
                reasoningOutputTokens: try container.decodeIfPresent(Int.self, forKey: .reasoningOutputTokens) ?? 0
            )
            guard schemaVersion == 1,
                  spanID.range(of: #"^[A-Za-z0-9_-]{6,64}$"#, options: .regularExpression) != nil,
                  (try? accounting.validate(inputTokens: Int.max, outputTokens: Int.max)) != nil
            else {
                throw TokenUsageValidationError.invalidRequiredField
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(schemaVersion, forKey: .schemaVersion)
            try container.encode(spanID, forKey: .spanID)
            try container.encodeIfPresent(aiTool, forKey: .aiTool)
            try container.encode(accounting.uncachedInputTokens, forKey: .uncachedInputTokens)
            try container.encode(accounting.cacheCreationInputTokens, forKey: .cacheCreationInputTokens)
            try container.encode(accounting.cacheReadInputTokens, forKey: .cacheReadInputTokens)
            try container.encode(accounting.reasoningOutputTokens, forKey: .reasoningOutputTokens)
        }

        static func hasOnlyAllowedKeys(_ object: [String: Any]) -> Bool {
            let allowedKeys = Set(CodingKeys.allCases.map(\.rawValue))
            return Set(object.keys).isSubset(of: allowedKeys)
        }
    }
}
