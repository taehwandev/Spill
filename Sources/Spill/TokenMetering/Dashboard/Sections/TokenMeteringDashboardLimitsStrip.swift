import SwiftUI

/// One-row strip of per-tool remaining-limit chips under the dashboard
/// header. Each chip shows the shared remaining-ratio ring plus the tool's
/// most constrained limit; clicking opens a popover listing every named
/// limit with countdowns and captured-at freshness. Tools without snapshots
/// render nothing, so the strip disappears entirely when no limits are known.
struct TokenMeteringDashboardLimitsStrip: View {
    let snapshots: [TokenUsageLimitSnapshot]
    let language: TokenMeteringLanguage

    @State private var popoverTool: TokenUsageAITool?

    private static let toolOrder: [TokenUsageAITool] = [.codex, .claude, .antigravity]

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

private extension TokenMeteringDashboardLimitsStrip {
    struct ToolGroup {
        let tool: TokenUsageAITool
        let snapshots: [TokenUsageLimitSnapshot]
        let gauges: [TokenUsageLimitSnapshot]
        let extraCount: Int
    }

    static let fiveHourWindowMinutes = 300
    static let weeklyWindowMinutes = 10_080

    var toolGroups: [ToolGroup] {
        Self.toolOrder.compactMap { tool in
            let toolSnapshots = snapshots.filter { $0.aiTool == tool }
            guard !toolSnapshots.isEmpty else {
                return nil
            }
            // Every chip renders the same fixed slots in the same order —
            // five-hour then weekly — so the basis is comparable across
            // tools. Extra named limits and credit balances stay in the
            // popover behind a +n indicator.
            var gauges = [Self.fiveHourWindowMinutes, Self.weeklyWindowMinutes]
                .compactMap { windowGauge(minutes: $0, in: toolSnapshots) }
            if gauges.isEmpty,
               let fallback = TokenUsageLimitSnapshotStore.mostConstrained(in: toolSnapshots)
                   ?? toolSnapshots.first(where: { $0.remainingCredits != nil }) {
                gauges = [fallback]
            }
            guard !gauges.isEmpty else {
                return nil
            }
            return ToolGroup(
                tool: tool,
                snapshots: toolSnapshots,
                gauges: gauges,
                extraCount: toolSnapshots.count - gauges.count
            )
        }
    }

    /// The slot gauge for a window length. When a tool carries several limits
    /// on the same window (Codex general weekly plus model-specific weeklies),
    /// the plain window limit represents the slot and the rest count as +n.
    func windowGauge(minutes: Int, in toolSnapshots: [TokenUsageLimitSnapshot]) -> TokenUsageLimitSnapshot? {
        let group = toolSnapshots.filter { $0.windowMinutes == minutes && $0.remainingPercent != nil }
        if group.count > 1 {
            let plainLabels: Set<String> = ["5-hour", "Weekly"]
            return group.first { plainLabels.contains($0.label) }
                ?? TokenUsageLimitSnapshotStore.mostConstrained(in: group)
        }
        return group.first
    }

    func limitChip(for group: ToolGroup) -> some View {
        Button {
            popoverTool = group.tool
        } label: {
            HStack(spacing: 6) {
                Text(compactToolName(group.tool))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.8))

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

                if group.extraCount > 0 {
                    Text("+\(group.extraCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
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
        let gauges = group.gauges
            .map { "\(slotLabel(for: $0)) \(headlineValue(for: $0))" }
            .joined(separator: ", ")
        return "\(group.tool.dashboardLabel(language: language)) \(gauges)"
    }

    func limitPopover(for group: ToolGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.tool.dashboardLabel(language: language))
                .font(.system(size: 12, weight: .semibold))

            ForEach(group.snapshots, id: \.limitKey) { snapshot in
                HStack(spacing: 8) {
                    TokenUsageLimitRing(snapshot: snapshot, diameter: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(detailTitle(for: snapshot))
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                        Text(detailSubtitle(for: snapshot))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 200, alignment: .leading)
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
        switch gauge.windowMinutes {
        case Self.fiveHourWindowMinutes:
            return "5h"
        case Self.weeklyWindowMinutes:
            return "Wk"
        default:
            return gauge.label
        }
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
        parts.append(
            TokenMeteringL10n.limitsCapturedAt(
                TokenUsageLimitSnapshot.shortDateFormatter.string(from: snapshot.capturedAt),
                language: language
            )
        )
        return parts.joined(separator: " · ")
    }

    func detailTitle(for snapshot: TokenUsageLimitSnapshot) -> String {
        "\(snapshot.label) \(headlineValue(for: snapshot))"
    }

    func detailSubtitle(for snapshot: TokenUsageLimitSnapshot) -> String {
        var parts: [String] = []
        if let resetsAt = snapshot.resetsAt {
            parts.append(
                TokenMeteringL10n.limitsResetsAt(
                    TokenUsageLimitSnapshot.shortDateFormatter.string(from: resetsAt),
                    language: language
                )
            )
        }
        parts.append(
            TokenMeteringL10n.limitsCapturedAt(
                TokenUsageLimitSnapshot.shortDateFormatter.string(from: snapshot.capturedAt),
                language: language
            )
        )
        return parts.joined(separator: " · ")
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

    func formattedPercent(_ value: Double) -> String {
        value >= 10 ? String(format: "%.0f", value) : String(format: "%.1f", value)
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
        let fraction = (remaining ?? 100) / 100
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0.02, fraction))
                .stroke(ringColor(remaining: remaining), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
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
