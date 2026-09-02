import SwiftUI

/// One-row strip of per-tool remaining-limit chips under the dashboard
/// header. Each chip shows the shared remaining-ratio ring for every window
/// the tool actually reports, plus how old the reading is; clicking opens a
/// popover naming every limit and its remaining value. Reset time, capture
/// stamp and source live in each row's tooltip rather than under it, because
/// a second line on every row read as noise instead of as context. Tools
/// without snapshots render nothing, so the strip disappears entirely when no
/// limits are known.
///
/// Nothing here refreshes on a clock, because none of the sources do: every
/// gauge comes from a file the tool itself writes while it runs. A chip is
/// therefore always an "as of" reading, and says so once it stops being
/// recent, rather than presenting a stale number as the current one.
struct TokenMeteringDashboardLimitsStrip: View {
    let snapshots: [TokenUsageLimitSnapshot]
    /// Every tool the user has not hidden. A chip is drawn for each one even
    /// with no reading, because a chip that comes and goes is harder to read
    /// than one that is simply blank until its tool reports again.
    var tools: Set<TokenUsageAITool> = []
    let language: TokenMeteringLanguage

    @State private var popoverTool: TokenUsageAITool?

    private static let toolOrder: [TokenUsageAITool] = [.codex, .claude, .antigravity]

    /// Tools that hold a blank chip while waiting for a reading, because a
    /// reading can still arrive for them. Antigravity fetches its window
    /// percentages live and persists none, so a blank chip there would mean
    /// "never" rather than "not yet" — it is left out of the row instead. It
    /// is not special-cased anywhere else: the moment a real Antigravity
    /// reading exists it appears here on its own, with no code change.
    private static let placeholderTools: Set<TokenUsageAITool> = [.codex, .claude]

    var body: some View {
        let groups = toolGroups
        if !groups.isEmpty {
            HStack(spacing: 8) {
                Text(TokenMeteringL10n.text(.limitsTitle, language: language))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(groups, id: \.tool) { group in
                    limitChip(for: group)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

/// Chip grouping, kept internal so the rule that every visible tool holds a
/// chip can be verified directly rather than through a rendered view.
extension TokenMeteringDashboardLimitsStrip {
    struct ToolGroup {
        let tool: TokenUsageAITool
        let snapshots: [TokenUsageLimitSnapshot]
        let gauges: [TokenUsageLimitSnapshot]
        let extraCount: Int
        /// Age of the least recently refreshed reading behind the chip: the
        /// honest "as of" for everything the chip stands for, including the
        /// limits that fell behind `+n` or lost their value entirely.
        let age: TimeInterval
        /// True when any of the tool's readings is older than the window it
        /// measured, so at least one number here cannot describe the window
        /// the user is in now.
        let outlivesItsWindow: Bool
    }

    /// Why a chip has no value to show. A limit that was read once and whose
    /// window has since closed unread is a different state from one that was
    /// never read at all, and the difference is what the reader needs: the
    /// first says the number went out of date, the second that none arrived.
    static func emptyReason(for group: ToolGroup) -> TokenMeteringTextKey {
        group.snapshots.contains { $0.isExpiredReading }
            ? .limitsWindowClosedUnread
            : .limitsNoReading
    }

    /// How many gauges fit in one chip before the rest fall behind `+n`.
    static let slotCount = 2
    /// Below this, "as of" is noise; above it, the reading's age is part of
    /// what the number means.
    static let staleThreshold: TimeInterval = 30 * 60

    var toolGroups: [ToolGroup] {
        let now = Date()
        // Tools that get a blank placeholder, plus every tool that actually
        // has a reading. The second half is what lets a tool with no
        // placeholder still appear once its data exists.
        let visible = tools.intersection(Self.placeholderTools)
            .union(snapshots.map(\.aiTool))
        return Self.toolOrder.filter(visible.contains).map { tool in
            let toolSnapshots = snapshots.filter { $0.aiTool == tool }
            var gauges = Self.slotGauges(in: toolSnapshots)
            if gauges.isEmpty,
               let fallback = toolSnapshots.first(where: { $0.remainingCredits != nil })
                   ?? TokenUsageLimitSnapshotStore.mostConstrained(in: toolSnapshots) {
                gauges = [fallback]
            }
            return ToolGroup(
                tool: tool,
                snapshots: toolSnapshots,
                gauges: gauges,
                extraCount: max(0, toolSnapshots.count - gauges.count),
                age: toolSnapshots.map { $0.age(at: now) }.max() ?? 0,
                // Each reading is measured against its own window rather than
                // against the shortest one on the chip, so a limit that lost
                // its value — and therefore its slot — still marks the chip as
                // no longer current instead of quietly ceding that judgement
                // to whichever gauge remains.
                outlivesItsWindow: toolSnapshots.contains { snapshot in
                    guard let window = snapshot.windowDuration else {
                        return false
                    }
                    return snapshot.age(at: now) > window
                }
            )
        }
    }

}

// MARK: - Chip rendering

private extension TokenMeteringDashboardLimitsStrip {
    func limitChip(for group: ToolGroup) -> some View {
        Button {
            popoverTool = group.tool
        } label: {
            HStack(spacing: 6) {
                Text(compactToolName(group.tool))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.8))

                if group.gauges.isEmpty {
                    // No value to show. The chip stays so the row keeps its
                    // shape, but it states nothing rather than inventing a
                    // percentage the tool never reported.
                    Text("—")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .help(TokenMeteringL10n.text(Self.emptyReason(for: group), language: language))
                }

                ForEach(group.gauges, id: \.limitKey) { gauge in
                    HStack(spacing: 4) {
                        TokenUsageLimitRing(snapshot: gauge, diameter: 12)
                        Text(gaugeText(for: gauge))
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.primary.opacity(0.8))
                            .lineLimit(1)
                    }
                    .help(chipTooltip(for: gauge))
                }

                if group.extraCount > 0, !group.gauges.isEmpty {
                    Text("+\(group.extraCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if group.age > Self.staleThreshold {
                    Text(TokenMeteringL10n.limitsAge(Self.compactDuration(group.age), language: language))
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            // A reading older than its own window can no longer describe the
            // current one. It stays visible — it is still the last thing the
            // tool said — but it stops looking current.
            .opacity(group.outlivesItsWindow ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityText(for: group)))
        .popover(
            isPresented: Binding(
                get: { popoverTool == group.tool },
                set: { if !$0 { popoverTool = nil } }
            )
        ) {
            limitPopover(for: group)
        }
    }

    func accessibilityText(for group: ToolGroup) -> String {
        guard !group.gauges.isEmpty else {
            return "\(group.tool.dashboardLabel(language: language)) "
                + TokenMeteringL10n.text(Self.emptyReason(for: group), language: language)
        }
        let gauges = group.gauges
            .map { "\(slotLabel(for: $0)) \(headlineValue(for: $0))" }
            .joined(separator: ", ")
        var text = "\(group.tool.dashboardLabel(language: language)) \(gauges)"
        if group.age > Self.staleThreshold {
            text += ", " + TokenMeteringL10n.limitsAge(
                Self.compactDuration(group.age),
                language: language
            )
        }
        return text
    }
}

// MARK: - Slot selection and formatting

/// Pure slot and label rules, kept out of the view body so they can be
/// verified directly: which gauges a chip shows is now a function of the
/// windows present in the data, not of a hardcoded pair.
extension TokenMeteringDashboardLimitsStrip {
    /// One gauge per window length the tool actually reports, shortest window
    /// first, capped at the chip's slot count.
    ///
    /// The slots used to be the fixed pair five-hour-then-weekly, which fought
    /// the data: a Codex plan whose only window is weekly sends no five-hour
    /// limit at all, and a plan change rewrites which windows exist. Reading
    /// the slots off `windowMinutes` means a new or renamed window appears
    /// without a release, and a window the account does not have simply is not
    /// drawn.
    static func slotGauges(in toolSnapshots: [TokenUsageLimitSnapshot]) -> [TokenUsageLimitSnapshot] {
        let windowed = toolSnapshots
            .filter { $0.remainingPercent != nil && $0.windowMinutes != nil }
            .sorted { $0.limitKey < $1.limitKey }
        let byWindow = Dictionary(grouping: windowed) { $0.windowMinutes ?? 0 }
        return byWindow.keys.sorted()
            .prefix(slotCount)
            .compactMap { representative(of: byWindow[$0] ?? []) }
    }

    /// When several limits share a window — a general weekly beside
    /// model-scoped weeklies — the unscoped limit represents the slot, because
    /// that is the one comparable across tools. Among equals the tightest one
    /// wins, since that is the limit that will actually stop the user.
    static func representative(of group: [TokenUsageLimitSnapshot]) -> TokenUsageLimitSnapshot? {
        let unscoped = group.filter { !$0.isScopedVariant }
        let candidates = unscoped.isEmpty ? group : unscoped
        return TokenUsageLimitSnapshotStore.mostConstrained(in: candidates) ?? candidates.first
    }

    /// "31%" for window gauges (remaining), "25,000" for credit balances.
    /// Estimated sources carry the mandated tilde prefix.
    func headlineValue(for snapshot: TokenUsageLimitSnapshot) -> String {
        let prefix = snapshot.source == .estimated ? "~" : ""
        if let remaining = snapshot.remainingPercent {
            return "\(prefix)\(formattedPercent(remaining))%"
        }
        if let credits = snapshot.remainingCredits {
            return prefix + (NumberFormatter.tokenUsageFull.string(from: NSNumber(value: credits)) ?? "\(credits)")
        }
        return "—"
    }

    /// Remaining percents floor instead of round: 99.8% remaining must read
    /// "99", never a false "100", and 4.96% must not soften into "5.0".
    func formattedPercent(_ value: Double) -> String {
        if value >= 10 {
            return String(format: "%.0f", value.rounded(.down))
        }
        return String(format: "%.1f", (value * 10).rounded(.down) / 10)
    }

    /// One slot inside a chip: "5h ~31% (20:00)" / "Wk 29% (8/8)". The slot
    /// label names the window so every tool reads on the same basis, and the
    /// parenthesized stamp is that window's reset moment.
    func gaugeText(for gauge: TokenUsageLimitSnapshot) -> String {
        var text = "\(slotLabel(for: gauge)) \(headlineValue(for: gauge))"
        if let resetsAt = gauge.resetsAt {
            text += " (\(resetStamp(for: resetsAt)))"
        }
        return text
    }

    func slotLabel(for gauge: TokenUsageLimitSnapshot) -> String {
        guard let windowLabel = Self.slotLabel(windowMinutes: gauge.windowMinutes) else {
            return gauge.label
        }
        guard gauge.isScopedVariant else {
            return windowLabel
        }

        // Old on-disk Codex snapshots included the verbose window in `label`.
        // Trim those two legacy suffixes at render time so upgrades do not
        // briefly show "Weekly Wk" before the next capture refreshes them.
        var scopeLabel = gauge.label
        for suffix in [" Weekly", " 5-hour"] where scopeLabel.hasSuffix(suffix) {
            scopeLabel.removeLast(suffix.count)
        }
        return "\(scopeLabel) \(windowLabel)"
    }

    /// The window length as a compact unit, derived from the number rather
    /// than from a table of the windows that happened to exist when this was
    /// written: 300 reads "5h", 10080 reads "Wk", and a window nobody has
    /// shipped yet still gets a sensible label.
    static func slotLabel(windowMinutes: Int?) -> String? {
        guard let minutes = windowMinutes, minutes > 0 else {
            return nil
        }
        if minutes % 10_080 == 0 {
            let weeks = minutes / 10_080
            return weeks == 1 ? "Wk" : "\(weeks)w"
        }
        if minutes % 1_440 == 0 {
            return "\(minutes / 1_440)d"
        }
        if minutes % 60 == 0 {
            return "\(minutes / 60)h"
        }
        return "\(minutes)m"
    }

    /// "12m", "3h", "2d" — the coarsest unit that still says something.
    static func compactDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(max(1, minutes))m"
        }
        if minutes < 24 * 60 {
            return "\(minutes / 60)h"
        }
        return "\(minutes / (24 * 60))d"
    }
}

// MARK: - Popover and text formatting

private extension TokenMeteringDashboardLimitsStrip {
    func limitPopover(for group: ToolGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.tool.dashboardLabel(language: language))
                .font(.system(size: 12, weight: .semibold))

            if group.snapshots.isEmpty {
                Text(TokenMeteringL10n.text(.limitsNoReading, language: language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            ForEach(group.snapshots, id: \.limitKey) { snapshot in
                HStack(spacing: 8) {
                    TokenUsageLimitRing(snapshot: snapshot, diameter: 12)
                    Text(detailTitle(for: snapshot))
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                }
                .help(chipTooltip(for: snapshot))
            }
        }
        .padding(12)
        .frame(minWidth: 160, alignment: .leading)
    }

    /// Same-day resets show the clock time; later resets show the date.
    func resetStamp(for resetsAt: Date) -> String {
        if Calendar.autoupdatingCurrent.isDate(resetsAt, inSameDayAs: Date()) {
            return TokenUsageLimitSnapshot.shortTimeFormatter.string(from: resetsAt)
        }
        return TokenUsageLimitSnapshot.shortDayFormatter.string(from: resetsAt)
    }

    func compactToolName(_ tool: TokenUsageAITool) -> String {
        switch tool {
        case .antigravity:
            return "AGY"
        default:
            return tool.dashboardLabel(language: language)
        }
    }

    func chipTooltip(for snapshot: TokenUsageLimitSnapshot) -> String {
        var parts: [String] = []
        if let remaining = snapshot.remainingPercent {
            parts.append(
                TokenMeteringL10n.limitsPercentLeft(formattedPercent(remaining), language: language)
            )
        }
        if let resetsAt = snapshot.resetsAt {
            parts.append(
                TokenMeteringL10n.limitsResetsAt(
                    TokenUsageLimitSnapshot.shortDateFormatter.string(from: resetsAt),
                    language: language
                )
            )
        }
        parts.append(contentsOf: freshnessParts(for: snapshot))
        return parts.joined(separator: " · ")
    }

    /// Where the number came from and how old it is — the part of a limit
    /// reading that a passive, file-backed source makes load-bearing.
    func freshnessParts(for snapshot: TokenUsageLimitSnapshot) -> [String] {
        var parts = [
            TokenMeteringL10n.limitsCapturedAt(
                TokenUsageLimitSnapshot.shortDateFormatter.string(from: snapshot.capturedAt),
                language: language
            )
        ]
        let age = snapshot.age(at: Date())
        if age > Self.staleThreshold {
            parts.append(
                TokenMeteringL10n.limitsAge(Self.compactDuration(age), language: language)
            )
        }
        if snapshot.locallyReset {
            parts.append(TokenMeteringL10n.text(.limitsWindowReset, language: language))
        }
        if snapshot.isExpiredReading {
            parts.append(TokenMeteringL10n.text(.limitsWindowClosedUnread, language: language))
        }
        parts.append(
            TokenMeteringL10n.text(
                snapshot.source == .estimated ? .limitsSourceEstimated : .limitsSourceExact,
                language: language
            )
        )
        return parts
    }
}

// MARK: - Detail rows and value formatting

private extension TokenMeteringDashboardLimitsStrip {
    func detailTitle(for snapshot: TokenUsageLimitSnapshot) -> String {
        "\(snapshot.label) \(headlineValue(for: snapshot))"
    }

}

/// The shared remaining-ratio ring: an arc filled by the remaining fraction,
/// colored by threshold only. Credit balances render a full ring in the
/// default tint because they have no percentage to encode.
struct TokenUsageLimitRing: View {
    let snapshot: TokenUsageLimitSnapshot
    var diameter: CGFloat = 12

    var body: some View {
        let remaining = snapshot.remainingPercent
        // A credit balance has no percentage to encode and fills the ring; a
        // reading whose window closed unread has nothing to encode either, and
        // must not borrow that full ring — an empty track is the only shape
        // that reads as "unknown" rather than as "untouched".
        let fraction = (remaining ?? 100) / 100
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 2)
            if !snapshot.isExpiredReading {
                Circle()
                    .trim(from: 0, to: max(0.02, fraction))
                    .stroke(ringColor(remaining: remaining), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    private func ringColor(remaining: Double?) -> Color {
        guard let remaining else {
            return snapshot.aiTool.dashboardTint
        }
        if remaining <= 5 {
            return .red
        }
        if remaining <= 20 {
            return .orange
        }
        return snapshot.aiTool.dashboardTint
    }
}

extension TokenUsageLimitSnapshot {
    /// Short "8/8 12:46" style stamp shared by tooltips and popover detail.
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("Md HH:mm")
        return formatter
    }()

    /// "12:46" — chip reset stamp for a same-day reset.
    static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter
    }()

    /// "8/8" — chip reset stamp for a reset on a later day.
    static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter
    }()
}
