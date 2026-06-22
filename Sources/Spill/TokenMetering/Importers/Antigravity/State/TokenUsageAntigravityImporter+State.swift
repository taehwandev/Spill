import Foundation

extension TokenUsageAntigravityImporter {
    func readImportState() -> ImportState {
        guard let stateURL,
              let data = try? Data(contentsOf: stateURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawCursors = object["max_generation_index_by_source"] as? [String: Any]
        else {
            return ImportState(maxGenerationIndexBySource: [:])
        }

        var cursors = [String: Int]()
        for (key, value) in rawCursors {
            guard key.range(of: #"^[a-f0-9]{24}$"#, options: .regularExpression) != nil else {
                continue
            }
            if let intValue = value as? Int, intValue >= 0 {
                cursors[key] = intValue
            } else if let number = value as? NSNumber, number.intValue >= 0 {
                cursors[key] = number.intValue
            }
        }
        return ImportState(maxGenerationIndexBySource: cursors)
    }

    func writeImportState(_ state: ImportState) {
        guard let stateURL else {
            return
        }

        let object: [String: Any] = [
            "schema_version": 1,
            "ai_tool": "antigravity",
            "max_generation_index_by_source": state.maxGenerationIndexBySource,
            "privacy": "Contains only opaque conversation hashes and numeric generation cursors; no paths, prompts, responses, commands, logs, diffs, source, environment values, or secrets."
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
