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

        for deferredWrite in deferredWrites {
            try? FileManager.default.removeItem(at: deferredWrite.finalURL)
            try FileManager.default.moveItem(at: deferredWrite.temporaryURL, to: deferredWrite.finalURL)
        }

        for url in result.consumedURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
