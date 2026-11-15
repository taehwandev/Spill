import SwiftUI

/// The limit line inside one AI tool tab: up to two window gauges, a `+n`
/// count for the rest, and a disclosure that opens every reading for the tool.
/// It is its own button, separate from the tab's select button, so opening
/// limit detail never changes the tool filter.
struct TokenMeteringDashboardToolTabLimits: View {
    let group: TokenMeteringDashboardLimitsPresentation.ToolGroup
    let presentation: TokenMeteringDashboardLimitsPresentation

    @State private var isPopoverPresented = false
    @State private var isHovered = false

    var body: some View {
        let now = Date()

        Button {
            isPopoverPresented = true
        } label: {
            HStack(spacing: 8) {
                if group.gauges.isEmpty {
                    Text(TokenMeteringL10n.text(
                        TokenMeteringDashboardLimitsPresentation.emptyReason(for: group),
                        language: presentation.language
                    ))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                } else {
                    ForEach(group.gauges, id: \.limitKey) { gauge in
                        gaugeView(gauge, now: now)
                    }
                }

                Spacer(minLength: 0)

                // "+n" says there is more behind the button, so it takes the
                // chevron's place rather than competing with it for width.
                if group.extraCount > 0 && !group.gauges.isEmpty {
                    Text("+\(group.extraCount)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isHovered ? .secondary : .tertiary)
                        .accessibilityHidden(true)
                }
            }
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                Color.primary.opacity(isHovered ? 0.07 : 0.035),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isHovered = $0 }
        .help(TokenMeteringL10n.text(.limitsTitle, language: presentation.language))
        .accessibilityLabel(presentation.accessibilityText(for: group))
        .popover(isPresented: $isPopoverPresented) {
            popoverContent
        }
    }

    private func gaugeView(_ gauge: TokenUsageLimitSnapshot, now: Date) -> some View {
        HStack(spacing: 3) {
            // The window name is what makes the number readable, so it never
            // truncates; the row scales down as a whole instead.
            Text(presentation.slotLabel(for: gauge))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            TokenUsageLimitRing(snapshot: gauge, diameter: 11)
            Text(presentation.headlineValue(for: gauge))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
            // A reading older than the stale threshold is marked in place;
            // the tooltip and accessibility text carry the exact age.
            if TokenMeteringDashboardLimitsPresentation.ageLabel(for: gauge, at: now, language: presentation.language) != nil {
                Image(systemName: "clock")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .opacity(TokenMeteringDashboardLimitsPresentation.outlivesWindow(gauge, at: now) ? 0.55 : 1)
        .help(presentation.chipTooltip(for: gauge))
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.tool.dashboardLabel(language: presentation.language))
                .font(.system(size: 12, weight: .semibold))

            if group.snapshots.isEmpty {
                Text(TokenMeteringL10n.text(.limitsNoReading, language: presentation.language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            ForEach(group.snapshots, id: \.limitKey) { snapshot in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        TokenUsageLimitRing(snapshot: snapshot, diameter: 12)
                        Text(presentation.detailTitle(for: snapshot))
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                    }
                    if let resetsAt = snapshot.resetsAt {
                        Text(TokenMeteringL10n.limitsResetsAt(
                            presentation.resetStamp(for: resetsAt),
                            language: presentation.language
                        ))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                    }
                }
                .help(presentation.chipTooltip(for: snapshot))
            }
        }
        .padding(12)
        .frame(minWidth: 180, alignment: .leading)
    }
}
