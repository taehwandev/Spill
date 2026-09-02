import Foundation

/// Claude limit readings harvested from Claude Code's status line payload.
///
/// Claude Code hands a status line script a `rate_limits` object on every
/// render. Unlike `~/.claude.json`'s cached utilization — rewritten only when
/// something fetches usage, so a whole window can be spent in silence — this
/// arrives continuously while the tool runs. Spill cannot receive it directly,
/// so the installed status line adapter writes the numbers to a small file and
/// this capture reads them, the same shape of arrangement as the Stop hook.
///
/// Readings are tagged `server_exact` rather than `client_cache` because the
/// distinction those tags carry is not who computed the number but whether the
/// source keeps writing while the tool runs. That property is what makes a
/// locally derived post-reset value sound, and the status line has it: Claude
/// allowance cannot be spent from this machine without Claude Code running,
/// and while it runs the line renders.
///
/// Privacy: the adapter extracts only numeric limit fields, window identifiers
/// and reset timestamps, and this capture reads only those.
struct TokenUsageClaudeStatuslineCapture {
    let readingURL: URL?
    let now: () -> Date

    init(
        readingURL: URL? = TokenUsageClaudeStatuslineCapture.defaultReadingURL(),
        now: @escaping () -> Date = Date.init
    ) {
        self.readingURL = readingURL
        self.now = now
    }

    static func defaultReadingURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("limit-inbox", isDirectory: true)
            .appendingPathComponent("claude-statusline.json")
    }

    /// Merges the harvested reading when it is newer than whatever Claude
    /// already has stored. The cache capture and this one describe the same
    /// limits from different sources, so the fresher reading wins rather than
    /// whichever happened to run last.
    @discardableResult
    func captureLatestSnapshots(into store: TokenUsageLimitSnapshotStore) -> Bool {
        let snapshots = latestSnapshots()
        guard let capturedAt = snapshots.first?.capturedAt else {
            return false
        }
        let newestStored = store.snapshots(for: .claude).map(\.capturedAt).max()
        if let newestStored, newestStored >= capturedAt {
            return false
        }
        store.mergeSnapshots(for: .claude, with: snapshots)
        return true
    }

    func latestSnapshots() -> [TokenUsageLimitSnapshot] {
        guard let readingURL,
              let data = try? Data(contentsOf: readingURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return []
        }
        return Self.snapshots(reading: root, now: now())
    }

    static func snapshots(reading: [String: Any], now: Date) -> [TokenUsageLimitSnapshot] {
        guard let windows = reading["windows"] as? [[String: Any]] else {
            return []
        }
        let capturedAt = (reading["captured_at"] as? String)
            .flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:)) ?? now

        return windows.compactMap { window in
            guard let minutes = intValue(window["window_minutes"]), minutes > 0,
                  let usedPercent = doubleValue(window["used_percent"])
            else {
                return nil
            }
            let resetsAt = (window["resets_at"] as? String)
                .flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:))
            return TokenUsageLimitSnapshot(
                aiTool: .claude,
                limitKey: limitKey(forWindowMinutes: minutes),
                label: label(forWindowMinutes: minutes),
                usedPercent: max(0, min(100, usedPercent)),
                remainingCredits: nil,
                windowMinutes: minutes,
                resetsAt: resetsAt,
                capturedAt: capturedAt,
                source: .serverExact
            )
        }
    }

    /// The keys the cached-utilization capture already mints, so a reading from
    /// either source updates the same limit instead of adding a duplicate chip.
    private static func limitKey(forWindowMinutes minutes: Int) -> String {
        switch minutes {
        case 300:
            return "session_5h"
        case 10_080:
            return "week_all"
        default:
            return "window_\(minutes)m"
        }
    }

    private static func label(forWindowMinutes minutes: Int) -> String {
        switch minutes {
        case 300:
            return "5-hour"
        case 10_080:
            return "Weekly"
        default:
            return "\(minutes)m"
        }
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let double = value as? Double {
            return Int(double)
        }
        return nil
    }
}
