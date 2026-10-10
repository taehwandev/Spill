import Foundation

/// Decodes only the native status envelope and fixed quota fields. Free-form
/// response text, descriptions, conversation IDs and account data are ignored.
enum TokenUsageAntigravityQuotaParser {
    private struct Report: Decodable {
        let status: String
        let numTurns: Int
        let command: Command
    }

    private struct Command: Decodable {
        let name: String
        let data: Quotas
    }

    private struct Quotas: Decodable {
        let groups: [Group]
    }

    private struct Group: Decodable {
        let name: String
        let buckets: [Bucket]
    }

    private struct Bucket: Decodable {
        let id: String
        let window: String
        let remainingFraction: Double?
        let resetTime: String?
        let disabled: Bool?
    }

    static func parse(_ data: Data, capturedAt: Date) -> [TokenUsageLimitSnapshotStore.CompleteGroup] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard data.count <= 1_048_576,
              let report = try? decoder.decode(Report.self, from: data),
              report.status == "SUCCESS", report.command.name == "usage",
              report.numTurns == 0
        else { return [] }

        var seenPools = Set<String>()
        var result: [TokenUsageLimitSnapshotStore.CompleteGroup] = []
        for group in report.command.data.groups {
            guard let pool = pool(for: group.name), seenPools.insert(pool.key).inserted else { continue }
            var snapshots: [TokenUsageLimitSnapshot] = []
            var seenWindows = Set<String>()
            var malformed = false
            for bucket in group.buckets {
                guard let window = window(for: bucket.window),
                      bucket.id == "\(pool.bucketPrefix)-\(window.key)"
                else { continue }
                guard seenWindows.insert(window.key).inserted else {
                    malformed = true
                    break
                }
                if bucket.disabled == true { continue }
                guard let fraction = bucket.remainingFraction,
                      fraction.isFinite, (0...1).contains(fraction),
                      let resetTime = bucket.resetTime, let reset = parseDate(resetTime)
                else {
                    malformed = true
                    break
                }
                snapshots.append(TokenUsageLimitSnapshot(
                    aiTool: .antigravity,
                    limitKey: "agy_quota:\(pool.key):\(window.key)",
                    label: "\(pool.label) \(window.label)",
                    usedPercent: (1 - fraction) * 100,
                    remainingCredits: nil,
                    windowMinutes: window.minutes,
                    resetsAt: reset,
                    capturedAt: capturedAt,
                    source: .clientCache
                ))
            }
            // A malformed pool is not authoritative removal. Other complete
            // pools may still refresh, while this one's prior readings age.
            guard !malformed, !snapshots.isEmpty else { continue }
            result.append(.init(
                keyPrefix: "agy_quota:\(pool.key):",
                capturedAt: capturedAt,
                snapshots: snapshots
            ))
        }
        return result
    }

    private static func pool(for name: String) -> (key: String, label: String, bucketPrefix: String)? {
        switch name {
        case "Gemini Models": return ("gemini", "Gemini", "gemini")
        case "Claude and GPT models": return ("claude_gpt", "Claude/GPT", "3p")
        default: return nil
        }
    }

    private static func window(for name: String) -> (key: String, label: String, minutes: Int)? {
        switch name {
        case "5h": return ("5h", "5-hour", 300)
        case "weekly": return ("weekly", "Weekly", 10_080)
        default: return nil
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
