import CryptoKit
import Foundation

extension TokenUsageClaudeCodeImporter {
    static func defaultProjectsDirectory() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true)
    }

    static func defaultLabelTimelineURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("label-context", isDirectory: true)
            .appendingPathComponent("claude-timeline.jsonl")
    }

    static func defaultStateURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("session-state", isDirectory: true)
            .appendingPathComponent("claude-active-importer-state.json")
    }

    static func sourceStateKey(for sessionID: String) -> String {
        opaqueHash(sessionID)
    }

    static func opaqueHash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(24).description
    }

    static func safeModel(_ value: String) -> String {
        value.range(of: #"^[A-Za-z0-9_.:-]{2,80}$"#, options: .regularExpression) != nil
            ? value
            : "claude-unknown"
    }

    static func safeAdd(_ a: Int, _ b: Int) -> Int? {
        let (result, overflow) = a.addingReportingOverflow(b)
        return overflow ? nil : result
    }
}
