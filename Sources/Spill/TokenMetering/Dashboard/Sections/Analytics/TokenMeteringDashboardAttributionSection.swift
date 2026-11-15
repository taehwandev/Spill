import SwiftUI

/// "Where did the tokens go": the AI tool split beside the raw input
/// accounting (fresh / cache write / cache read / unsplit) breakdown.
struct TokenMeteringDashboardAttributionSection: View {
    @ObservedObject var store: TokenUsageDashboardStore
    let language: TokenMeteringLanguage
    let showsPlaceholder: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if showsPlaceholder {
                TokenMeteringDashboardLoadingDistributionPanel(
                    title: t(.aiToolDistribution),
                    subtitle: t(.aiToolDistributionSubtitle),
                    infoTitle: t(.aiToolInfoTitle),
                    infoDetail: t(.aiToolInfoDetail),
                    tint: .teal,
                    minimumHeight: 180,
                    placeholderHeight: 118
                )

                TokenMeteringDashboardLoadingDistributionPanel(
                    title: t(.inputAccounting),
                    subtitle: t(.inputAccountingSubtitle),
                    infoTitle: t(.inputAccountingInfoTitle),
                    infoDetail: t(.inputAccountingInfoDetail),
                    tint: .indigo,
                    minimumHeight: 180,
                    placeholderHeight: 118
                )
            } else {
                TokenMeteringDashboardDistributionPanel(
                    rows: store.snapshot.toolRows,
                    title: t(.aiToolDistribution),
                    subtitle: t(.aiToolDistributionSubtitle),
                    infoTitle: t(.aiToolInfoTitle),
                    infoDetail: t(.aiToolInfoDetail),
                    emptyTitle: t(.noAIToolData),
                    idPrefix: "tool_chart",
                    tint: .teal,
                    rowTint: aiToolTint,
                    panelMinimumHeight: 180,
                    rowsMinimumHeight: 118,
                    language: language,
                    marker: store.liveUpdateMarker,
                    isLiveUpdated: { store.isLiveUpdated($0) }
                )

                TokenMeteringDashboardDistributionPanel(
                    rows: store.snapshot.inputAccounting.rows,
                    title: t(.inputAccounting),
                    subtitle: t(.inputAccountingSubtitle),
                    infoTitle: t(.inputAccountingInfoTitle),
                    infoDetail: t(.inputAccountingInfoDetail),
                    emptyTitle: t(.noInputAccountingData),
                    idPrefix: "input_accounting",
                    tint: .indigo,
                    panelMinimumHeight: 180,
                    rowsMinimumHeight: 118,
                    language: language,
                    marker: store.liveUpdateMarker,
                    isLiveUpdated: { store.isLiveUpdated($0) }
                )
            }
        }
    }
}

extension TokenMeteringDashboardAttributionSection {
    private func aiToolTint(for row: TokenUsageDashboardBarRow) -> Color {
        TokenUsageAITool(rawValue: row.id.lowercased())?.dashboardTint ?? .secondary
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
