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
        let headline: TokenUsageLimitSnapshot
    }

    var toolGroups: [ToolGroup] {
        Self.toolOrder.compactMap { tool in
            let toolSnapshots = snapshots.filter { $0.aiTool == tool }
            // The chip headline is the most constrained percentage gauge;
            // credit-only tools fall back to their credits reading.
            guard let headline = TokenUsageLimitSnapshotStore.mostConstrained(in: toolSnapshots)
                ?? toolSnapshots.first(where: { $0.remainingCredits != nil })
            else {
                return nil
            }
            return ToolGroup(tool: tool, snapshots: toolSnapshots, headline: headline)
        }
    }

    func limitChip(for group: ToolGroup) -> some View {
        Button {
            popoverTool = group.tool
        } label: {
            HStack(spacing: 5) {
                TokenUsageLimitRing(snapshot: group.headline, diameter: 12)

                Text(chipText(for: group.headline))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .help(chipTooltip(for: group.headline))
        .accessibilityLabel(Text("\(group.tool.dashboardLabel(language: language)) \(chipText(for: group.headline))"))
        .popover(
            isPresented: Binding(
                get: { popoverTool == group.tool },
                set: { if !$0 { popoverTool = nil } }
            )
        ) {
            limitPopover(for: group)
        }
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

    /// The chip must say which tool it describes — "Weekly 30%" alone is
    /// unreadable in a strip that mixes tools.
    func chipText(for snapshot: TokenUsageLimitSnapshot) -> String {
        var text = "\(compactToolName(snapshot.aiTool)) · \(snapshot.label) \(headlineValue(for: snapshot))"
        if let resetsAt = snapshot.resetsAt {
            text += " · \(TokenUsageLimitSnapshot.shortDateFormatter.string(from: resetsAt))"
        }
        return text
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
    /// Short "8/8 12:46" style stamp shared by chip text and tooltips.
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("Md HH:mm")
        return formatter
    }()
}
