import Foundation

extension TokenUsageClaudeCodeImporter {
    struct AssistantTurn {
        let requestId: String
        let sessionID: String
        let timestamp: String
        let model: String
        let turnIndex: Int
        let inputTokens: Int
        let spanInputTokens: Int
        let outputTokens: Int
    }

    func parseTurns(
        from url: URL,
        after byteOffset: Int,
        sourceSessionID: String,
        startingTurnIndex: Int
    ) -> (turns: [AssistantTurn], newByteOffset: Int, nextTurnIndex: Int) {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ([], byteOffset, startingTurnIndex)
        }
        defer { try? handle.close() }

        if byteOffset > 0 {
            guard (try? handle.seek(toOffset: UInt64(byteOffset))) != nil else {
                return ([], byteOffset, startingTurnIndex)
            }
        }

        guard let data = try? handle.readToEnd(), !data.isEmpty else {
            return ([], byteOffset, startingTurnIndex)
        }

        let newByteOffset = byteOffset + data.count
        let lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
        var turns = [AssistantTurn]()
        var turnIndex = startingTurnIndex

        for lineData in lines {
            guard let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let parsedRecord = assistantTurn(
                    from: object,
                    sourceSessionID: sourceSessionID,
                    turnIndex: turnIndex
                  )
            else { continue }

            if let parsedTurn = parsedRecord.turn {
                turns.append(parsedTurn)
            }
            if parsedRecord.consumesTurnIndex {
                turnIndex += 1
            }
        }

        return (turns, newByteOffset, turnIndex)
    }

    private func assistantTurn(
        from object: [String: Any],
        sourceSessionID: String,
        turnIndex: Int
    ) -> (turn: AssistantTurn?, consumesTurnIndex: Bool)? {
        let message = object["message"] as? [String: Any]
        let role = message?["role"] as? String
        let type = object["type"] as? String
        guard role == "assistant" || type == "assistant" else {
            return nil
        }

        let usage = (message?["usage"] as? [String: Any]) ?? (object["usage"] as? [String: Any])
        guard let usage else {
            return nil
        }

        let usageAmounts = usageAmounts(usage)
        let inputTokens = usageAmounts.input
        let spanInputTokens = usageAmounts.spanInput
        let outputTokens = usageAmounts.output
        guard inputTokens + outputTokens > 0 else {
            return (nil, true)
        }

        let sessionID = stringValue(object["sessionId"])
            ?? stringValue(object["session_id"])
            ?? sourceSessionID
        let requestID = stringValue(object["requestId"])
            ?? stringValue(object["request_id"])
            ?? stringValue(message?["id"])
            ?? stringValue(object["uuid"])
            ?? ""
        let timestamp = stringValue(object["timestamp"]) ?? stringValue(message?["timestamp"])
        guard let timestamp else {
            return (nil, true)
        }

        return (AssistantTurn(
            requestId: requestID,
            sessionID: sessionID,
            timestamp: timestamp,
            model: stringValue(message?["model"]) ?? stringValue(object["model"]) ?? "claude-unknown",
            turnIndex: turnIndex,
            inputTokens: inputTokens,
            spanInputTokens: spanInputTokens,
            outputTokens: outputTokens
        ), true)
    }

    private func usageAmounts(
        _ usage: [String: Any],
        includeIterations: Bool = true
    ) -> (input: Int, spanInput: Int, output: Int) {
        let inputTokens = safeUsageToken(usage["input_tokens"])
        let cacheCreationTokens = cacheCreationTokens(from: usage)
        let cacheReadTokens = safeUsageToken(usage["cache_read_input_tokens"])
        let outputTokens = safeUsageToken(usage["output_tokens"])

        if inputTokens > 0 || cacheCreationTokens > 0 || cacheReadTokens > 0 || outputTokens > 0 {
            return (
                inputTokens + cacheCreationTokens + cacheReadTokens,
                inputTokens + cacheCreationTokens,
                outputTokens
            )
        }

        guard includeIterations,
              let iterations = usage["iterations"] as? [Any]
        else {
            return (0, 0, 0)
        }

        return iterations.reduce(into: (input: 0, spanInput: 0, output: 0)) { totals, item in
            guard let object = item as? [String: Any] else { return }
            let nestedUsage = (object["usage"] as? [String: Any]) ?? object
            let nestedAmounts = usageAmounts(nestedUsage, includeIterations: false)
            totals.input += nestedAmounts.input
            totals.spanInput += nestedAmounts.spanInput
            totals.output += nestedAmounts.output
        }
    }

    private func cacheCreationTokens(from usage: [String: Any]) -> Int {
        let direct = safeUsageToken(usage["cache_creation_input_tokens"])
        if direct > 0 {
            return direct
        }

        guard let detail = usage["cache_creation"] as? [String: Any] else {
            return 0
        }
        return detail.values.reduce(0) { $0 + safeUsageToken($1) }
    }

    private func safeUsageToken(_ value: Any?) -> Int {
        switch value {
        case let value as Int:
            return max(0, value)
        case let value as Double where value.rounded(.towardZero) == value:
            return max(0, Int(value))
        case let value as NSNumber where CFGetTypeID(value) != CFBooleanGetTypeID():
            return max(0, value.intValue)
        default:
            return 0
        }
    }

    private func stringValue(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else {
            return nil
        }
        return value
    }
}
