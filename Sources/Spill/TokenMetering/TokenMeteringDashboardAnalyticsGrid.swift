import SwiftUI

struct TokenMeteringDashboardAnalyticsGrid: View {
    @ObservedObject var store: TokenUsageDashboardStore
    let language: TokenMeteringLanguage
    let showsPlaceholder: Bool
    let hasEvents: Bool
    let settingsAction: () -> Void
    let developerOptionsAction: () -> Void
    @State private var hoveredRowID: String? = nil

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
                        tint: .teal
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
                TokenMeteringDashboardTrendChart(buckets: trendBuckets, language: language)
            }
        }
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
        tint: Color
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
                compactChartRows(rows, idPrefix: idPrefix, tint: tint)
                    .frame(height: 160)
            }
        }
    }

    private func compactChartRows(
        _ rows: [TokenUsageDashboardBarRow],
        idPrefix: String,
        tint: Color
    ) -> some View {
        let visibleRows = Array(rows.filter { $0.ratio > 0 }.prefix(5))

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(visibleRows) { row in
                let liveUpdateID = "\(idPrefix):\(row.id)"
                let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
                let isHovered = hoveredRowID == liveUpdateID

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        TokenMeteringLiveUpdateDot(isActive: isLiveUpdated, marker: store.liveUpdateMarker)
                        Text(row.title)
                            .font(.system(size: 11, weight: isHovered ? .bold : .semibold))
                            .lineLimit(1)
                            .foregroundStyle(isHovered ? tint : .primary)
                        Spacer(minLength: 6)
                        Text(row.value)
                            .font(.system(size: 10, weight: isHovered ? .black : .bold, design: .monospaced))
                            .foregroundStyle(isHovered ? .primary : .secondary)
                            .contentTransition(.numericText())
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: isHovered ? [tint, tint.opacity(0.7)] : [tint.opacity(0.85), tint.opacity(0.55)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: Swift.max(CGFloat(6), geometry.size.width * CGFloat(row.ratio)))
                                .shadow(color: tint.opacity(isHovered ? 0.35 : 0.0), radius: 3, x: 0, y: 1)
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
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
