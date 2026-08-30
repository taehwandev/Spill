import Foundation

/// Exact Claude remaining-limit snapshots from the client's own cached
/// utilization state. Claude Code persists the server's `/usage` answer —
/// per-window used percent and reset time — in its state file, so Spill can
/// surface the same numbers the user sees in `/usage` without any network
/// access. The values are server-computed but read from a local cache, so
/// snapshots are tagged `client_cache` and carry the cache's fetch time as
/// `capturedAt`.
///
/// The client owns that state's shape and has already changed it once, which
/// silently demoted every Claude gauge to an estimate. So the payload is
/// located structurally — the key name is a hint, not the contract — entries
/// are recognised by the fields a window limit must have rather than by the
/// vendor's names for them, and every pass writes a content-free diagnostic
/// saying what it found.
///
/// Privacy: the state file also holds unrelated runtime state. This capture
/// reads only numeric percents, reset timestamps, window kinds, and safe model
/// display names out of the limit entries, and never records any other value.
final class TokenUsageClaudeLimitCapture: @unchecked Sendable {
    /// The key the client used at the time of writing. Tried first so the
    /// common case costs one lookup; its absence is not a failure.
    static let preferredCacheKey = "cachedUsageUtilization"

    private let stateFileURL: URL?
    private let diagnostics: TokenUsageLimitCaptureDiagnostics?
    private let now: () -> Date

    init(
        stateFileURL: URL? = TokenUsageClaudeLimitCapture.defaultStateFileURL(),
        diagnostics: TokenUsageLimitCaptureDiagnostics? = TokenUsageLimitCaptureDiagnostics(),
        now: @escaping () -> Date = Date.init
    ) {
        self.stateFileURL = stateFileURL
        self.diagnostics = diagnostics
        self.now = now
    }

    static func defaultStateFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json")
    }

    /// Returns true when at least one exact snapshot was stored, in which case
    /// estimated Claude gauges should not be produced.
    @discardableResult
    func captureLatestSnapshots(into store: TokenUsageLimitSnapshotStore) -> Bool {
        guard let stateFileURL else {
            return false
        }
        let data = try? Data(contentsOf: stateFileURL)
        let root = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]

        let located = root.flatMap(Self.locateUtilizationCache)
        let snapshots = located.map {
            Self.snapshots(cachedUsageUtilization: $0.cache, now: now())
        } ?? []

        diagnostics?.write(
            TokenUsageLimitCaptureDiagnostics.Record(
                stateFileFound: data != nil,
                stateFileParsed: root != nil,
                utilizationFound: located != nil,
                foundByStructuralScan: located?.foundByStructuralScan ?? false,
                limitEntryCount: located.map { Self.limitEntries(in: $0.cache)?.count ?? 0 } ?? 0,
                windowedLimitCount: snapshots.filter { $0.windowMinutes != nil }.count
            )
        )

        guard !snapshots.isEmpty else {
            return false
        }
        store.mergeSnapshots(for: .claude, with: snapshots)
        return true
    }
}

extension TokenUsageClaudeLimitCapture {
    struct LocatedCache {
        let cache: [String: Any]
        let foundByStructuralScan: Bool
    }

    /// Finds the cached utilization payload by shape rather than by key name.
    /// The preferred key wins when it still holds limit entries; otherwise
    /// top-level values are scanned in sorted key order (deterministic, one
    /// level deep) for the first object that carries them. A rename therefore
    /// degrades to "found it somewhere else, and the diagnostic says so"
    /// instead of to silent estimates.
    static func locateUtilizationCache(in root: [String: Any]) -> LocatedCache? {
        if let preferred = root[preferredCacheKey] as? [String: Any],
           limitEntries(in: preferred) != nil {
            return LocatedCache(cache: preferred, foundByStructuralScan: false)
        }
        for key in root.keys.sorted() where key != preferredCacheKey {
            guard let candidate = root[key] as? [String: Any],
                  limitEntries(in: candidate) != nil
            else {
                continue
            }
            return LocatedCache(cache: candidate, foundByStructuralScan: true)
        }
        return nil
    }

    /// The limit entries inside a candidate payload, at either nesting the
    /// client has used. An array only counts when its entries carry a numeric
    /// percentage, so an unrelated `limits` key cannot be mistaken for usage.
    static func limitEntries(in candidate: [String: Any]) -> [[String: Any]]? {
        let nested = (candidate["utilization"] as? [String: Any])?["limits"] as? [[String: Any]]
        guard let limits = nested ?? (candidate["limits"] as? [[String: Any]]),
              limits.contains(where: { $0["percent"] is Double || $0["percent"] is Int })
        else {
            return nil
        }
        return limits
    }

    /// Maps the cache's limit entries to snapshots.
    ///
    /// An entry qualifies as a window gauge when it carries a percentage *and*
    /// a reset moment — the structure of a windowed limit — which admits a
    /// renamed window while still excluding the spend and credit entries that
    /// share the array. Expired entries are kept rather than dropped: the
    /// store resolves a closed window to its post-reset value, and dropping
    /// them is what used to make a chip vanish whenever Claude sat unused.
    static func snapshots(
        cachedUsageUtilization: [String: Any]?,
        now: Date
    ) -> [TokenUsageLimitSnapshot] {
        guard let cache = cachedUsageUtilization,
              let limits = limitEntries(in: cache)
        else {
            return []
        }
        let capturedAt = (cache["fetchedAtMs"] as? Double).map {
            Date(timeIntervalSince1970: $0 / 1_000)
        } ?? now

        return limits.compactMap { entry in
            guard let percent = doubleValue(entry["percent"]),
                  let resetsAt = (entry["resets_at"] as? String).flatMap(parseResetDate)
            else {
                return nil
            }
            let kind = (entry["kind"] as? String) ?? "limit"
            let window = window(kind: kind, entry: entry)
            return TokenUsageLimitSnapshot(
                aiTool: .claude,
                limitKey: window.key,
                label: window.label,
                usedPercent: max(0, min(100, percent)),
                remainingCredits: nil,
                windowMinutes: window.minutes,
                resetsAt: resetsAt,
                capturedAt: capturedAt,
                source: .clientCache
            )
        }
    }

    /// Known kinds keep their established key, label, and window length so the
    /// chip slots stay stable. An unknown kind still becomes a gauge, but with
    /// no window length: it lands in the popover behind the `+n` indicator
    /// rather than claiming a slot it may not belong in.
    private static func window(
        kind: String,
        entry: [String: Any]
    ) -> (key: String, label: String, minutes: Int?) {
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
            return ("kind_\(kind.lowercased())", humanized(kind), nil)
        }
    }

    /// "weekly_burst" reads as "Weekly Burst"; the kind slug is a safe enum
    /// label, never user content.
    static func humanized(_ kind: String) -> String {
        kind
            .split(whereSeparator: { $0 == "_" || $0 == "-" })
            .map(\.capitalized)
            .joined(separator: " ")
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
