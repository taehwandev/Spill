import Foundation

/// Exact Claude remaining-limit snapshots from the client's own cached
/// utilization state. Claude Code persists the server's `/usage` answer —
/// per-window used percent and reset time — in its state file, so Spill can
/// surface the same numbers the user sees in `/usage` without any network
/// access. The values are server-computed but read from a local cache, so
/// snapshots are tagged `client_cache` and carry the cache's fetch time as
/// `capturedAt`.
///
/// Privacy: the state file also holds unrelated runtime state. This capture
/// decodes only the cached-utilization limit entries — numeric percents,
/// reset timestamps, window kinds, and safe model display names — and never
/// reads any other key.
final class TokenUsageClaudeLimitCapture: @unchecked Sendable {
    private let stateFileURL: URL?
    private let now: () -> Date

    init(
        stateFileURL: URL? = TokenUsageClaudeLimitCapture.defaultStateFileURL(),
        now: @escaping () -> Date = Date.init
    ) {
        self.stateFileURL = stateFileURL
        self.now = now
    }

    static func defaultStateFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json")
    }

    /// Returns true when at least one fresh exact snapshot was stored, in
    /// which case estimated Claude gauges should not be produced.
    @discardableResult
    func captureLatestSnapshots(into store: TokenUsageLimitSnapshotStore) -> Bool {
        guard let stateFileURL,
              let data = try? Data(contentsOf: stateFileURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return false
        }
        let snapshots = Self.snapshots(
            cachedUsageUtilization: root["cachedUsageUtilization"] as? [String: Any],
            now: now()
        )
        guard !snapshots.isEmpty else {
            return false
        }
        store.replaceSnapshots(for: .claude, with: snapshots)
        return true
    }

    /// Maps the cache's `limits` entries to snapshots. Entries whose reset
    /// time has already passed describe an expired window and are dropped —
    /// if everything is stale the caller falls back to estimated gauges.
    static func snapshots(
        cachedUsageUtilization: [String: Any]?,
        now: Date
    ) -> [TokenUsageLimitSnapshot] {
        guard let cache = cachedUsageUtilization,
              let utilization = cache["utilization"] as? [String: Any],
              let limits = utilization["limits"] as? [[String: Any]]
        else {
            return []
        }
        let capturedAt = (cache["fetchedAtMs"] as? Double).map {
            Date(timeIntervalSince1970: $0 / 1_000)
        } ?? now

        return limits.compactMap { entry in
            guard let kind = entry["kind"] as? String,
                  let percent = entry["percent"] as? Double
            else {
                return nil
            }
            let resetsAt = (entry["resets_at"] as? String).flatMap(parseResetDate)
            if let resetsAt, resetsAt <= now {
                return nil
            }
            guard let window = window(kind: kind, entry: entry) else {
                return nil
            }
            return TokenUsageLimitSnapshot(
                aiTool: .claude,
                limitKey: window.key,
                label: window.label,
                usedPercent: percent,
                remainingCredits: nil,
                windowMinutes: window.minutes,
                resetsAt: resetsAt,
                capturedAt: capturedAt,
                source: .clientCache
            )
        }
    }

    private static func window(
        kind: String,
        entry: [String: Any]
    ) -> (key: String, label: String, minutes: Int)? {
        switch kind {
        case "session":
            return ("session_5h", "5-hour", 300)
        case "weekly_all":
            return ("week_all", "Weekly", 10_080)
        case "weekly_scoped":
            // Model-scoped weekly limits label themselves with the safe model
            // display name and land behind the chip's +n indicator because
            // the plain "Weekly" limit represents the weekly slot.
            let scope = entry["scope"] as? [String: Any]
            let model = scope?["model"] as? [String: Any]
            let name = (model?["display_name"] as? String) ?? "Scoped"
            return ("weekly_scoped_\(name.lowercased())", name, 10_080)
        default:
            // Unknown kinds are skipped rather than guessed: the cache also
            // carries spend/credit entries that are not window limits.
            return nil
        }
    }

    private static func parseResetDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        let plain = ISO8601DateFormatter()
        return plain.date(from: value)
    }
}
