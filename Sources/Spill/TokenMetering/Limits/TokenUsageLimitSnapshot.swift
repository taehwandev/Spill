import Foundation

/// One captured "how much is left" reading for one named limit of one tool.
/// Snapshots are display state, deliberately separate from the strict
/// token-usage event schema: they contain only numeric percentages, credit
/// counts, window lengths, timestamps, and enum labels.
struct TokenUsageLimitSnapshot: Codable, Equatable {
    /// How trustworthy the number is; the UI labels anything that is not
    /// server-provided, so an estimate can never masquerade as exact.
    enum Source: String, Codable {
        case serverExact = "server_exact"
        case clientCache = "client_cache"
        case estimated

        /// True when the tool rewrites its limit state as it runs, so the
        /// absence of a newer reading is itself evidence the tool went
        /// unused. Codex writes `rate_limits` into its session file on every
        /// turn, which is what makes a locally derived post-reset value sound.
        /// A client cache is refreshed only when the tool decides to — for
        /// Claude Code, when the user runs `/usage` — so silence there says
        /// nothing about whether the allowance was spent.
        var refreshesWhileTheToolRuns: Bool {
            self == .serverExact
        }
    }

    let aiTool: TokenUsageAITool
    /// The tool's own limit identifier when it provides one (Codex
    /// `limit_id` plus window), otherwise a Spill-defined slug.
    let limitKey: String
    /// Human-readable label ("Weekly", "5-hour", "Spark Weekly", "Credits").
    let label: String
    /// Percent of the window already used (0...100). Nil for credit balances.
    let usedPercent: Double?
    /// Remaining credit balance. Nil for percentage windows.
    let remainingCredits: Int?
    let windowMinutes: Int?
    let resetsAt: Date?
    let capturedAt: Date
    let source: Source
    /// True when the reading was not read from the tool at all: its window had
    /// already closed, so Spill derived the post-reset value locally. The UI
    /// labels these, because "full again" is only known to have been true at
    /// the reset moment — the tool may have been used since without Spill
    /// seeing it.
    let locallyReset: Bool

    init(
        aiTool: TokenUsageAITool,
        limitKey: String,
        label: String,
        usedPercent: Double?,
        remainingCredits: Int?,
        windowMinutes: Int?,
        resetsAt: Date?,
        capturedAt: Date,
        source: Source,
        locallyReset: Bool = false
    ) {
        self.aiTool = aiTool
        self.limitKey = limitKey
        self.label = label
        self.usedPercent = usedPercent
        self.remainingCredits = remainingCredits
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
        self.capturedAt = capturedAt
        self.source = source
        self.locallyReset = locallyReset
    }

    /// Snapshot files written before `locallyReset` existed must keep loading;
    /// limits are additive display state and a decode failure would blank the
    /// whole strip.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        aiTool = try container.decode(TokenUsageAITool.self, forKey: .aiTool)
        limitKey = try container.decode(String.self, forKey: .limitKey)
        label = try container.decode(String.self, forKey: .label)
        usedPercent = try container.decodeIfPresent(Double.self, forKey: .usedPercent)
        remainingCredits = try container.decodeIfPresent(Int.self, forKey: .remainingCredits)
        windowMinutes = try container.decodeIfPresent(Int.self, forKey: .windowMinutes)
        resetsAt = try container.decodeIfPresent(Date.self, forKey: .resetsAt)
        capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        source = try container.decode(Source.self, forKey: .source)
        locallyReset = try container.decodeIfPresent(Bool.self, forKey: .locallyReset) ?? false
    }

    var remainingPercent: Double? {
        usedPercent.map { max(0, min(100, 100 - $0)) }
    }

    /// True for a limit whose window closed while its source stayed silent:
    /// there is still a capture stamp saying when it was last read, but no
    /// value that describes the window the user is in now. The UI draws these
    /// as "unknown" rather than as a gauge, because the alternative is to
    /// state a percentage nobody measured.
    var isExpiredReading: Bool {
        usedPercent == nil && remainingCredits == nil
    }

    var windowDuration: TimeInterval? {
        windowMinutes.map { TimeInterval($0) * 60 }
    }

    func age(at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(capturedAt))
    }

    /// True for a limit that narrows an existing window to one model rather
    /// than describing the whole window, so the unscoped limit represents the
    /// window in a chip slot and the scoped ones fall behind `+n`. Spill mints
    /// every limit key, so this is a local naming convention and not a vendor
    /// string being matched.
    var isScopedVariant: Bool {
        if limitKey.hasPrefix("weekly_scoped_") {
            return true
        }
        return aiTool == .codex
            && limitKey.contains(":")
            && !limitKey.hasPrefix("codex:")
    }
}

extension TokenUsageLimitSnapshot {
    /// The reading as it stands at `now`.
    ///
    /// A stored snapshot keeps aging after capture, and once its window's
    /// reset moment passes the recorded percentage describes a window that no
    /// longer exists. What replaces it depends on whether the source would
    /// have told us about use in the meantime.
    ///
    /// For a source that writes while the tool runs, the post-reset value is
    /// derivable locally and exactly — the allowance was full again at
    /// `resetsAt`, and any spending since would have left a newer reading —
    /// so the window is reset instead of being dropped, which is what used to
    /// make chips disappear whenever a tool sat unused. The next reset moment
    /// is *not* derivable (session windows open on first use, not on a fixed
    /// clock), so it is cleared rather than guessed, and `capturedAt` moves to
    /// the reset moment because that is when the new value is known to have
    /// been true.
    ///
    /// For a cache the tool refreshes on demand, none of that holds: the user
    /// can spend a whole window without a single new reading being written.
    /// Deriving "full again" there reports an unused allowance to someone who
    /// may have just exhausted it, which is worse than reporting nothing, so
    /// the reading becomes unknown and keeps its original capture stamp.
    func resolved(at now: Date) -> TokenUsageLimitSnapshot {
        guard let resetsAt, resetsAt <= now, usedPercent != nil else {
            return self
        }
        guard source.refreshesWhileTheToolRuns else {
            return expiredWithoutReread()
        }
        return TokenUsageLimitSnapshot(
            aiTool: aiTool,
            limitKey: limitKey,
            label: label,
            usedPercent: 0,
            remainingCredits: remainingCredits,
            windowMinutes: windowMinutes,
            resetsAt: nil,
            capturedAt: resetsAt,
            source: source,
            locallyReset: true
        )
    }

    /// The same reading with its percentage withdrawn: the window it measured
    /// is gone and no replacement was read. `capturedAt` stays where it was,
    /// because that is still the last moment anything was known, and the next
    /// reset is cleared for the same reason a reset window clears it.
    private func expiredWithoutReread() -> TokenUsageLimitSnapshot {
        TokenUsageLimitSnapshot(
            aiTool: aiTool,
            limitKey: limitKey,
            label: label,
            usedPercent: nil,
            remainingCredits: remainingCredits,
            windowMinutes: windowMinutes,
            resetsAt: nil,
            capturedAt: capturedAt,
            source: source,
            locallyReset: false
        )
    }
}
