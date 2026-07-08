import Foundation

extension TokenUsageClaudeCodeImporter {
    struct ImportState {
        var byteOffsetBySource: [String: Int]
        var nextTurnIndexBySource: [String: Int]
        // Tracks requestIds already imported per session to block cross-batch Bug #2
        // duplicates: Claude Code writes the same requestId 2-3x with slightly different
        // timestamps, so different span_ids would be generated in separate read batches.
        var emittedRequestIDsBySource: [String: Set<String>]
    }

    func readImportState() -> ImportState {
        guard let stateURL,
              let data = try? Data(contentsOf: stateURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ImportState(byteOffsetBySource: [:], nextTurnIndexBySource: [:], emittedRequestIDsBySource: [:])
        }

        // Legacy state files lack next_turn_index_by_source. Without it the byte
        // offsets would produce turn_index values that start at 0 for each new
        // batch, diverging from Python's sequential per-file indexing and breaking
        // span_id dedup. Reset to a fresh state so all sessions re-scan from 0.
        guard object["next_turn_index_by_source"] != nil else {
            return ImportState(byteOffsetBySource: [:], nextTurnIndexBySource: [:], emittedRequestIDsBySource: [:])
        }

        var offsets = [String: Int]()
        if let rawOffsets = object["byte_offset_by_source"] as? [String: Any] {
            for (key, value) in rawOffsets {
                guard key.range(of: #"^[a-f0-9]{24}$"#, options: .regularExpression) != nil else { continue }
                if let intValue = value as? Int, intValue >= 0 {
                    offsets[key] = intValue
                } else if let number = value as? NSNumber, number.intValue >= 0 {
                    offsets[key] = number.intValue
                }
            }
        }

        var turnIndices = [String: Int]()
        if let rawIndices = object["next_turn_index_by_source"] as? [String: Any] {
            for (key, value) in rawIndices {
                guard key.range(of: #"^[a-f0-9]{24}$"#, options: .regularExpression) != nil else { continue }
                if let intValue = value as? Int, intValue >= 0 {
                    turnIndices[key] = intValue
                } else if let number = value as? NSNumber, number.intValue >= 0 {
                    turnIndices[key] = number.intValue
                }
            }
        }

        var emittedRequestIDs = [String: Set<String>]()
        if let rawEmitted = object["emitted_request_ids_by_source"] as? [String: Any] {
            for (key, value) in rawEmitted {
                guard key.range(of: #"^[a-f0-9]{24}$"#, options: .regularExpression) != nil else { continue }
                if let array = value as? [String] {
                    let ids = array.filter { !$0.isEmpty && $0.count <= 64 }
                    if !ids.isEmpty {
                        emittedRequestIDs[key] = Set(ids)
                    }
                }
            }
        }

        return ImportState(
            byteOffsetBySource: offsets,
            nextTurnIndexBySource: turnIndices,
            emittedRequestIDsBySource: emittedRequestIDs
        )
    }

    func writeImportState(_ state: ImportState) {
        guard let stateURL else { return }

        var serializedEmitted = [String: [String]]()
        for (key, ids) in state.emittedRequestIDsBySource where !ids.isEmpty {
            serializedEmitted[key] = Array(ids).sorted()
        }

        let object: [String: Any] = [
            "schema_version": 1,
            "ai_tool": "claude",
            "byte_offset_by_source": state.byteOffsetBySource,
            "next_turn_index_by_source": state.nextTurnIndexBySource,
            "emitted_request_ids_by_source": serializedEmitted,
            "privacy": "Contains only opaque session hashes, numeric offsets/indices, and opaque request UUIDs; no paths, prompts, responses, commands, logs, diffs, source, environment values, or secrets."
        ]

        do {
            try fileManager.createDirectory(
                at: stateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            try data.write(to: stateURL, options: [.atomic])
        } catch {
            return
        }
    }
}
