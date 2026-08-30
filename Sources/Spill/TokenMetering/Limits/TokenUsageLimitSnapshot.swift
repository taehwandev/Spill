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
        limitKey.hasPrefix("weekly_scoped_")
    }
}

extension TokenUsageLimitSnapshot {
    /// The reading as it stands at `now`.
    ///
    /// A stored snapshot keeps aging after capture, and once its window's
    /// reset moment passes the recorded percentage describes a window that no
    /// longer exists. That is derivable locally and exactly — the allowance
    /// was full again at `resetsAt` — so the window is reset instead of being
    /// dropped, which is what used to make chips disappear whenever a tool sat
    /// unused. The next reset moment is *not* derivable (session windows open
    /// on first use, not on a fixed clock), so it is cleared rather than
    /// guessed, and `capturedAt` moves to the reset moment because that is
    /// when the new value is known to have been true.
    func resolved(at now: Date) -> TokenUsageLimitSnapshot {
        guard let resetsAt, resetsAt <= now, usedPercent != nil else {
            return self
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
}
