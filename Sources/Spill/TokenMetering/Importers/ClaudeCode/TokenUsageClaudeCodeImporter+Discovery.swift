import Foundation

extension TokenUsageClaudeCodeImporter {
    struct SessionFile {
        let url: URL
        let sessionID: String
    }

    func discoverSessionFiles() -> [SessionFile] {
        guard let enumerator = fileManager.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results = [SessionFile]()
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true
            else { continue }

            let sessionID = url.deletingPathExtension().lastPathComponent
            guard sessionID.range(of: #"^[0-9a-f-]{32,}$"#, options: .regularExpression) != nil else {
                continue
            }
            results.append(SessionFile(url: url, sessionID: sessionID))
        }
        return results
    }
}
