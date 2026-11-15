import SwiftUI

/// Work Type and Work Step distributions. Each panel leads with its top rows so
/// the first read still shows which work dominated; the long tail expands in
/// place.
struct TokenMeteringDashboardWorkBreakdownSection: View {
    @ObservedObject var store: TokenUsageDashboardStore
    let language: TokenMeteringLanguage
    let showsPlaceholder: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if showsPlaceholder {
                TokenMeteringDashboardLoadingDistributionPanel(
                    title: t(.workflowBreakdown),
                    subtitle: t(.workflowBreakdownSubtitle),
                    infoTitle: t(.workflowInfoTitle),
                    infoDetail: t(.workflowInfoDetail),
                    tint: .blue
                )

                TokenMeteringDashboardLoadingDistributionPanel(
                    title: t(.stageBreakdown),
                    subtitle: t(.stageBreakdownSubtitle),
                    infoTitle: t(.stageInfoTitle),
                    infoDetail: t(.stageInfoDetail),
                    tint: .purple
                )
            } else {
                TokenMeteringDashboardDistributionPanel(
                    rows: store.snapshot.taskRows,
                    title: t(.workflowBreakdown),
                    subtitle: t(.workflowBreakdownSubtitle),
                    infoTitle: t(.workflowInfoTitle),
                    infoDetail: t(.workflowInfoDetail),
                    emptyTitle: t(.noWorkflowData),
                    idPrefix: "task_chart",
                    tint: .blue,
                    language: language,
                    marker: store.liveUpdateMarker,
                    isLiveUpdated: { store.isLiveUpdated($0) }
                )

                TokenMeteringDashboardDistributionPanel(
                    rows: store.snapshot.stageRows,
                    title: t(.stageBreakdown),
                    subtitle: t(.stageBreakdownSubtitle),
                    infoTitle: t(.stageInfoTitle),
                    infoDetail: t(.stageInfoDetail),
                    emptyTitle: t(.noStageData),
                    idPrefix: "stage_chart",
                    tint: .purple,
                    language: language,
                    marker: store.liveUpdateMarker,
                    isLiveUpdated: { store.isLiveUpdated($0) }
                )
            }
        }
    }
}

extension TokenMeteringDashboardWorkBreakdownSection {
    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
