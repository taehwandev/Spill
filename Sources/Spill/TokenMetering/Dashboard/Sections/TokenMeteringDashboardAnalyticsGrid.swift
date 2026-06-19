import SwiftUI

struct TokenMeteringDashboardAnalyticsGrid: View {
    @ObservedObject var store: TokenUsageDashboardStore
    let language: TokenMeteringLanguage
    let showsPlaceholder: Bool
    let hasEvents: Bool
    let settingsAction: () -> Void
    let developerOptionsAction: () -> Void
    @State private var hoveredRowID: String? = nil
    @State private var selectedTrendBucketID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsPlaceholder {
                loadingAnalyticsGrid
            } else if !hasEvents {
                emptyDashboardGuide
            } else {
                if shouldShowTrendChart {
                    trendChart
                }

                HStack(alignment: .top, spacing: 14) {
                    distributionPanel(
                        rows: store.snapshot.toolRows,
                        title: t(.aiToolDistribution),
                        subtitle: t(.aiToolDistributionSubtitle),
                        infoTitle: t(.aiToolInfoTitle),
                        infoDetail: t(.aiToolInfoDetail),
                        emptyTitle: t(.noAIToolData),
                        idPrefix: "tool_chart",
                        tint: .teal,
                        rowTint: aiToolTint
                    )

                    distributionPanel(
                        rows: store.snapshot.taskRows,
                        title: t(.workflowBreakdown),
                        subtitle: t(.workflowBreakdownSubtitle),
                        infoTitle: t(.workflowInfoTitle),
                        infoDetail: t(.workflowInfoDetail),
                        emptyTitle: t(.noWorkflowData),
                        idPrefix: "task_chart",
                        tint: .blue
                    )
                }

                HStack(alignment: .top, spacing: 14) {
                    distributionPanel(
                        rows: store.snapshot.stageRows,
                        title: t(.stageBreakdown),
                        subtitle: t(.stageBreakdownSubtitle),
                        infoTitle: t(.stageInfoTitle),
                        infoDetail: t(.stageInfoDetail),
                        emptyTitle: t(.noStageData),
                        idPrefix: "stage_chart",
                        tint: .purple
                    )

                    distributionPanel(
                        rows: store.snapshot.sourceRows.filter { $0.id != "unknown" },
                        title: t(.sourceBreakdown),
                        subtitle: t(.sourceBreakdownSubtitle),
                        infoTitle: t(.sourceInfoTitle),
                        infoDetail: t(.sourceInfoDetail),
                        emptyTitle: t(.noSourceBreakdown),
                        idPrefix: "source_chart",
                        tint: .orange
                    )
                }
            }
        }
    }

    private var trendTitle: String {
        t(.trendTitle)
    }

    private var trendSubtitle: String {
        t(.trendSubtitle)
    }

    private var shouldShowTrendChart: Bool {
        guard store.snapshot.selectedCalendarDayID == nil else {
            return false
        }

        switch store.selectedPeriod {
        case .sevenDays, .thirtyDays, .all:
            return true
        case .today:
            return false
        }
    }

    private var trendChart: some View {
        let trendBuckets = store.snapshot.trendBuckets
        let hasData = trendBuckets.contains { $0.hasEvents }
        let selectedBucket = selectedTrendBucket(in: trendBuckets)

        return TokenMeteringDashboardPanel(
            title: trendTitle,
            subtitle: trendSubtitle
        ) {
            if !hasData {
                TokenMeteringDashboardEmptyMessage(
                    title: t(.noTrendData),
                    detail: t(.waitingForEvents)
                )
            } else {
                VStack(alignment: .leading, spacing: 11) {
                    TokenMeteringDashboardTrendChart(
                        buckets: trendBuckets,
                        selectedBucketID: $selectedTrendBucketID,
                        defaultSelectedBucketID: selectedBucket?.id,
                        language: language
                    )

                    if let selectedBucket {
                        TokenMeteringDashboardTrendBucketSummary(bucket: selectedBucket, language: language)
                    }
                }
            }
        }
    }

    private func selectedTrendBucket(in buckets: [TokenUsageDashboardTrendBucket]) -> TokenUsageDashboardTrendBucket? {
        if let selectedTrendBucketID,
           let selectedBucket = buckets.first(where: { $0.id == selectedTrendBucketID && $0.hasEvents }) {
            return selectedBucket
        }

        return buckets.last { $0.hasEvents }
    }

    private var loadingAnalyticsGrid: some View {
        TokenMeteringDashboardLoadingAnalyticsGrid(
            shouldShowTrendChart: shouldShowTrendChart,
            trendTitle: trendTitle,
            trendSubtitle: trendSubtitle,
            aiToolTitle: t(.aiToolDistribution),
            aiToolSubtitle: t(.aiToolDistributionSubtitle),
            aiToolInfoTitle: t(.aiToolInfoTitle),
            aiToolInfoDetail: t(.aiToolInfoDetail),
            workflowTitle: t(.workflowBreakdown),
            workflowSubtitle: t(.workflowBreakdownSubtitle),
            workflowInfoTitle: t(.workflowInfoTitle),
            workflowInfoDetail: t(.workflowInfoDetail),
            stageTitle: t(.stageBreakdown),
            stageSubtitle: t(.stageBreakdownSubtitle),
            stageInfoTitle: t(.stageInfoTitle),
            stageInfoDetail: t(.stageInfoDetail),
            sourceTitle: t(.sourceBreakdown),
            sourceSubtitle: t(.sourceBreakdownSubtitle),
            sourceInfoTitle: t(.sourceInfoTitle),
            sourceInfoDetail: t(.sourceInfoDetail)
        )
    }

    private var emptyDashboardGuide: some View {
        TokenMeteringDashboardOnboardingGuide(
            language: language,
            showsDeveloperOptions: store.isOnboardingPreviewEnabled && SpillBuildOptions.developerOptionsEnabled,
            settingsAction: settingsAction,
            developerOptionsAction: developerOptionsAction
        )
    }

    private func distributionPanel(
        rows: [TokenUsageDashboardBarRow],
        title: String,
        subtitle: String,
        infoTitle: String,
        infoDetail: String,
        emptyTitle: String,
        idPrefix: String,
        tint: Color,
        rowTint: ((TokenUsageDashboardBarRow) -> Color)? = nil
    ) -> some View {
        TokenMeteringDashboardPanel(
            title: title,
            subtitle: subtitle,
            infoTitle: infoTitle,
            infoDetail: infoDetail
        ) {
            let totalRatio = rows.reduce(0.0) { $0 + $1.ratio }
            if rows.isEmpty || totalRatio == 0 {
                TokenMeteringDashboardEmptyMessage(title: emptyTitle, detail: t(.waitingForEvents))
            } else {
                compactChartRows(rows, idPrefix: idPrefix, tint: tint, rowTint: rowTint)
                    .padding(.top, 10)
                    .frame(minHeight: 210, alignment: .topLeading)
            }
        }
    }

    private func compactChartRows(
        _ rows: [TokenUsageDashboardBarRow],
        idPrefix: String,
        tint: Color,
        rowTint: ((TokenUsageDashboardBarRow) -> Color)?
    ) -> some View {
        let visibleRows = Array(rows.filter { $0.ratio > 0 }.prefix(5))

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(visibleRows) { row in
                let liveUpdateID = "\(idPrefix):\(row.id)"
                let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
                let isHovered = hoveredRowID == liveUpdateID
                let effectiveTint = rowTint?(row) ?? tint

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        TokenMeteringLiveUpdateDot(isActive: isLiveUpdated, marker: store.liveUpdateMarker, tint: effectiveTint)
                        Text(row.title)
                            .font(.system(size: 11, weight: isHovered ? .bold : .semibold))
                            .lineLimit(1)
                            .foregroundStyle(isHovered ? effectiveTint : .primary)
                        Spacer(minLength: 6)
                        metricValue(row.value, tint: effectiveTint, isHovered: isHovered)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: isHovered ? [effectiveTint, effectiveTint.opacity(0.7)] : [effectiveTint.opacity(0.85), effectiveTint.opacity(0.55)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: Swift.max(CGFloat(6), geometry.size.width * CGFloat(row.ratio)))
                                .shadow(color: effectiveTint.opacity(isHovered ? 0.35 : 0.0), radius: 3, x: 0, y: 1)
                                .animation(.snappy(duration: 0.35), value: row.ratio)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.02) : Color.clear)
                )
                .offset(x: isHovered ? 2 : 0)
                .animation(.spring(response: 0.22, dampingFraction: 0.75), value: hoveredRowID)
                .onHover { hovering in
                    hoveredRowID = hovering ? liveUpdateID : nil
                }
                .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated && !isHovered, marker: store.liveUpdateMarker, cornerRadius: 7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func metricValue(_ value: String, tint: Color, isHovered: Bool) -> some View {
        let parts = metricValueParts(from: value)
        return HStack(spacing: 5) {
            Text(parts.primary)
                .font(.system(size: 10, weight: isHovered ? .black : .bold, design: .monospaced))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .contentTransition(.numericText())

            if let badge = parts.badge {
                metricValueBadge(badge, tint: tint, isHovered: isHovered)
            }
        }
    }

    private func metricValueBadge(_ value: String, tint: Color, isHovered: Bool) -> some View {
        Text(value)
            .font(.system(size: 8.5, weight: .black, design: .rounded))
            .lineLimit(1)
            .contentTransition(.numericText())
            .padding(.horizontal, 5)
            .frame(height: 17)
            .foregroundStyle(isHovered ? tint : tint.opacity(0.92))
            .background(tint.opacity(isHovered ? 0.16 : 0.10), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(tint.opacity(isHovered ? 0.30 : 0.18), lineWidth: 0.6)
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

    private func aiToolTint(for row: TokenUsageDashboardBarRow) -> Color {
        TokenUsageAITool(rawValue: row.id.lowercased())?.dashboardTint ?? .secondary
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}

private struct TokenMeteringDashboardTrendBucketSummary: View {
    let bucket: TokenUsageDashboardTrendBucket
    let language: TokenMeteringLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bucket.detail)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 8)

                Text(TokenMeteringL10n.localEventsDetail(eventCount: bucket.eventCount, language: language))
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            let visibleRows = Array(bucket.toolRows.filter { $0.ratio > 0 }.prefix(3))
            if !visibleRows.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(visibleRows) { row in
                        let tint = toolTint(for: row)
                        HStack(spacing: 7) {
                            Circle()
                                .fill(tint)
                                .frame(width: 6, height: 6)

                            Text(row.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                        .fill(Color.primary.opacity(0.05))
                                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                        .fill(tint.opacity(0.8))
                                        .frame(width: Swift.max(CGFloat(5), geometry.size.width * CGFloat(row.ratio)))
                                }
                            }
                            .frame(height: 5)

                            Text(row.value)
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func toolTint(for row: TokenUsageDashboardBarRow) -> Color {
        TokenUsageAITool(rawValue: row.id.lowercased())?.dashboardTint ?? .secondary
    }
}
