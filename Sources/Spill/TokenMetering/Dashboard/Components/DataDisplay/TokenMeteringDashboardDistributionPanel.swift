import SwiftUI

/// A ranked distribution panel. The first `collapsedRowLimit` rows answer
/// "what dominated" at a glance; the remaining rows stay one click away so a
/// long tail never pushes the Work Items table off the first screen.
struct TokenMeteringDashboardDistributionPanel: View {
    static let collapsedRowLimit = 5

    let rows: [TokenUsageDashboardBarRow]
    let title: String
    let subtitle: String
    let infoTitle: String
    let infoDetail: String
    let emptyTitle: String
    let idPrefix: String
    let tint: Color
    var rowTint: ((TokenUsageDashboardBarRow) -> Color)? = nil
    var panelMinimumHeight: CGFloat = 260
    var rowsMinimumHeight: CGFloat = 210
    let language: TokenMeteringLanguage
    let marker: TokenUsageLiveUpdateMarker
    let isLiveUpdated: (String) -> Bool
    @State private var hoveredRowID: String? = nil
    @State private var showsAllRows = false

    var body: some View {
        TokenMeteringDashboardPanel(
            title: title,
            subtitle: subtitle,
            infoTitle: infoTitle,
            infoDetail: infoDetail,
            minimumHeight: panelMinimumHeight
        ) {
            let totalRatio = rows.reduce(0.0) { $0 + $1.ratio }
            if rows.isEmpty || totalRatio == 0 {
                TokenMeteringDashboardEmptyMessage(title: emptyTitle, detail: t(.waitingForEvents))
            } else {
                compactChartRows
                    .padding(.top, 10)
                    .frame(minHeight: rowsMinimumHeight, alignment: .topLeading)
            }
        }
    }
}

extension TokenMeteringDashboardDistributionPanel {
    private var nonEmptyRows: [TokenUsageDashboardBarRow] {
        rows.filter { $0.ratio > 0 }
    }

    private var compactChartRows: some View {
        let allRows = nonEmptyRows
        let hiddenRowCount = Swift.max(0, allRows.count - Self.collapsedRowLimit)
        let visibleRows = showsAllRows ? allRows : Array(allRows.prefix(Self.collapsedRowLimit))
        // Split by tool only when the panel actually mixes tools; a single-tool scope keeps the
        // panel's own tint so the tool tab selection doesn't recolor every row.
        let showsToolSplit = Set(allRows.flatMap { $0.toolShares.map(\.tool) }).count > 1

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(visibleRows) { row in
                chartRow(row, showsToolSplit: showsToolSplit)
            }

            if hiddenRowCount > 0 {
                showAllRowsToggle(hiddenRowCount: hiddenRowCount)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func chartRow(_ row: TokenUsageDashboardBarRow, showsToolSplit: Bool) -> some View {
        let liveUpdateID = "\(idPrefix):\(row.id)"
        let isRowLiveUpdated = isLiveUpdated(liveUpdateID)
        let isHovered = hoveredRowID == liveUpdateID
        let effectiveTint = rowTint?(row) ?? tint

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                TokenMeteringLiveUpdateDot(isActive: isRowLiveUpdated, marker: marker, tint: effectiveTint)
                Text(row.title)
                    .font(.system(size: 11, weight: isHovered ? .bold : .semibold))
                    .lineLimit(1)
                    .foregroundStyle(isHovered ? effectiveTint : .primary)
                Spacer(minLength: 6)
                metricValue(row.value, isHovered: isHovered)
            }

            GeometryReader { geometry in
                let barWidth = Swift.max(CGFloat(6), geometry.size.width * CGFloat(row.ratio))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.075))
                    if showsToolSplit && !row.toolShares.isEmpty {
                        toolSplitBar(row.toolShares, width: barWidth, isHovered: isHovered)
                    } else {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: isHovered ? [effectiveTint, effectiveTint.opacity(0.75)] : [effectiveTint.opacity(0.9), effectiveTint.opacity(0.65)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: barWidth)
                    }
                }
            }
            .frame(height: 8)

            if showsToolSplit && !row.toolShares.isEmpty {
                toolShareCaption(row.toolShares, isHovered: isHovered)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.02) : Color.clear)
        )
        .onHover { hovering in
            hoveredRowID = hovering ? liveUpdateID : nil
        }
        .modifier(TokenMeteringLiveUpdateEffect(isActive: isRowLiveUpdated && !isHovered, marker: marker, cornerRadius: 7))
    }

    private func showAllRowsToggle(hiddenRowCount: Int) -> some View {
        Button {
            showsAllRows.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(showsAllRows ? t(.showFewerRows) : TokenMeteringL10n.showAllRows(count: hiddenRowCount, language: language))
                    .font(.system(size: 10, weight: .semibold))
                Image(systemName: showsAllRows ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityAddTraits(.isButton)
    }
}

extension TokenMeteringDashboardDistributionPanel {
    private func toolSplitBar(
        _ shares: [TokenUsageDashboardToolShare],
        width: CGFloat,
        isHovered: Bool
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(shares) { share in
                Rectangle()
                    .fill(share.tool.dashboardTint.opacity(isHovered ? 1.0 : 0.85))
                    .frame(width: width * CGFloat(share.ratio))
            }
        }
        .frame(width: width, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func toolShareCaption(_ shares: [TokenUsageDashboardToolShare], isHovered: Bool) -> some View {
        HStack(spacing: 10) {
            ForEach(shares) { share in
                HStack(spacing: 4) {
                    Circle()
                        .fill(share.tool.dashboardTint)
                        .frame(width: 6, height: 6)
                    Text(share.tool.compactDashboardLabel(language: language))
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(isHovered ? .primary : .secondary)
                    Text(TokenUsageDashboardSnapshot.formatPercentage(share.ratio * 100.0))
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(share.tool.dashboardTint)
                        .contentTransition(.numericText())
                }
                .lineLimit(1)
                .help("\(share.tool.dashboardLabel(language: language)) \(TokenUsageDashboardSnapshot.formatTokens(share.tokens))")
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func metricValue(_ value: String, isHovered: Bool) -> some View {
        let parts = metricValueParts(from: value)
        return HStack(spacing: 5) {
            Text(parts.primary)
                .font(.system(size: 10, weight: isHovered ? .black : .bold, design: .monospaced))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .contentTransition(.numericText())

            if let badge = parts.badge {
                metricValueBadge(badge, isHovered: isHovered)
            }
        }
    }

    /// Share badges stay neutral in every panel: color is reserved for tool
    /// identity in bars and legends, so a percentage never reads as a series.
    private func metricValueBadge(_ value: String, isHovered: Bool) -> some View {
        Text(value)
            .font(.system(size: 8.5, weight: .black, design: .rounded))
            .lineLimit(1)
            .contentTransition(.numericText())
            .padding(.horizontal, 5)
            .frame(height: 17)
            .foregroundStyle(isHovered ? Color.primary : Color.secondary)
            .background(Color.primary.opacity(isHovered ? 0.10 : 0.06), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.primary.opacity(isHovered ? 0.16 : 0.08), lineWidth: 0.6)
            }
    }

    private func metricValueParts(from value: String) -> (primary: String, badge: String?) {
        guard value.hasSuffix(")"),
              let range = value.range(of: " (", options: .backwards)
        else {
            return (value, nil)
        }

        let primary = String(value[..<range.lowerBound])
        let badgeStart = value.index(range.lowerBound, offsetBy: 2)
        let badgeEnd = value.index(before: value.endIndex)
        guard badgeStart < badgeEnd else {
            return (value, nil)
        }

        return (primary, String(value[badgeStart..<badgeEnd]))
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
