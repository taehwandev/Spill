import CryptoKit
import Foundation

extension TokenUsageAntigravityImporter {
    static func sourceStateKey(for source: ConversationDatabase) -> String {
        opaqueHash(source.url.deletingPathExtension().lastPathComponent)
    }

    static func defaultConversationsDirectory() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".gemini", isDirectory: true)
            .appendingPathComponent("antigravity-cli", isDirectory: true)
            .appendingPathComponent("conversations", isDirectory: true)
    }

    static func defaultLabelTimelineURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("label-context", isDirectory: true)
            .appendingPathComponent("antigravity-timeline.jsonl")
    }

    static func defaultDiagnosticsURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("diagnostics", isDirectory: true)
            .appendingPathComponent("antigravity-active-importer-last.json")
    }

    static func defaultStateURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("session-state", isDirectory: true)
            .appendingPathComponent("antigravity-active-importer-state.json")
    }

    static func opaqueHash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(24).description
    }
}
