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

    var remainingPercent: Double? {
        usedPercent.map { max(0, min(100, 100 - $0)) }
    }
}
