import Foundation

extension TokenUsageInboxReader {
    func hasQueuedInboxFiles() -> Bool {
        if let inboxURL,
           let urls = try? FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
           ),
           urls.contains(where: { $0.pathExtension == "json" || $0.pathExtension == "jsonl" }) {
            return true
        }

        if let inboxURL {
            let legacyInboxURL = inboxURL
                .deletingLastPathComponent()
                .appendingPathComponent("events-inbox.jsonl")
            return FileManager.default.fileExists(atPath: legacyInboxURL.path)
        }

        return false
    }

    func commit(_ result: ReadResult) throws {
        let deferredWrites = try result.deferredJSONLFiles.map { deferredFile in
            let temporaryURL = deferredFile.finalURL
                .deletingLastPathComponent()
                .appendingPathComponent(".\(deferredFile.finalURL.lastPathComponent).\(UUID().uuidString).tmp")
            try deferredFile.contents.write(to: temporaryURL, atomically: true, encoding: .utf8)
            return (temporaryURL: temporaryURL, finalURL: deferredFile.finalURL)
        }
        let rewrittenURLs = Set(deferredWrites.map(\.finalURL))

        for deferredWrite in deferredWrites {
            if FileManager.default.fileExists(atPath: deferredWrite.finalURL.path) {
                _ = try FileManager.default.replaceItemAt(
                    deferredWrite.finalURL,
                    withItemAt: deferredWrite.temporaryURL
                )
            } else {
                try FileManager.default.moveItem(at: deferredWrite.temporaryURL, to: deferredWrite.finalURL)
            }
        }

        for url in result.consumedURLs where !rewrittenURLs.contains(url) {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: accountingInboxURL(for: url))
        }
    }

    private func accountingInboxURL(for eventURL: URL) -> URL {
        eventURL.deletingPathExtension().appendingPathExtension("accounting")
    }
}
