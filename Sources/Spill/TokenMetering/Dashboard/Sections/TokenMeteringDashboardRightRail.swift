import SwiftUI

/// Secondary column beside the usage analytics: agent connection status,
/// model share, work label coverage, then setup.
struct TokenMeteringDashboardRightRail: View {
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject var aiStatusStore: AIStatusStore
    @ObservedObject var settings: SpillSettings
    let language: TokenMeteringLanguage
    let showsPlaceholder: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                agentStatusPanel
                modelPanel
                workflowUsagePanel
                setupPanel
            }
            // Starts level with the filter bar so the sidebar reads as a
            // full-height column beside the analysis.
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
    }
}

extension TokenMeteringDashboardRightRail {
    private var agentStatusPanel: some View {
        TokenMeteringDashboardAgentStatusPanel(
            aiStatusStore: aiStatusStore,
            settings: settings,
            language: language,
            appLanguage: settings.appLanguage
        )
    }

    private var modelPanel: some View {
        TokenMeteringDashboardRailPanel(
            title: t(.modelBreakdown),
            infoTitle: t(.modelInfoTitle),
            infoDetail: t(.modelInfoDetail)
        ) {
            VStack(spacing: 8) {
                if showsPlaceholder {
                    TokenMeteringDashboardCompactLoadingRows()
                } else {
                    TokenMeteringDashboardCompactSummaryRows(
                        rows: store.snapshot.modelRows.prefix(5),
                        emptyText: t(.noModelData),
                        idPrefix: "model",
                        marker: store.liveUpdateMarker,
                        isLiveUpdated: { store.isLiveUpdated($0) }
                    )
                }
            }
        }
    }

    private var workflowUsagePanel: some View {
        TokenMeteringDashboardRailPanel(
            title: t(.workflowUsage),
            infoTitle: t(.workflowUsageInfoTitle),
            infoDetail: t(.workflowUsageInfoDetail)
        ) {
            VStack(spacing: 8) {
                if showsPlaceholder {
                    TokenMeteringDashboardCompactLoadingRows()
                } else {
                    TokenMeteringDashboardCompactSummaryRows(
                        rows: store.snapshot.workflowUsage.rows,
                        emptyText: t(.noWorkflowUsageData),
                        idPrefix: "workflow_usage",
                        marker: store.liveUpdateMarker,
                        isLiveUpdated: { store.isLiveUpdated($0) }
                    )
                }
            }
        }
    }

    private var setupPanel: some View {
        TokenMeteringDashboardSetupPanel(
            aiStatusStore: aiStatusStore,
            language: language
        )
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
