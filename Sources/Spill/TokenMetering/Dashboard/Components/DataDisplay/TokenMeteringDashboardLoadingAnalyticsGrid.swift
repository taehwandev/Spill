import SwiftUI

struct TokenMeteringDashboardLoadingAnalyticsGrid: View {
    let shouldShowTrendChart: Bool
    let trendTitle: String
    let trendSubtitle: String
    let aiToolTitle: String
    let aiToolSubtitle: String
    let aiToolInfoTitle: String
    let aiToolInfoDetail: String
    let workflowTitle: String
    let workflowSubtitle: String
    let workflowInfoTitle: String
    let workflowInfoDetail: String
    let stageTitle: String
    let stageSubtitle: String
    let stageInfoTitle: String
    let stageInfoDetail: String
    let sourceTitle: String
    let sourceSubtitle: String
    let sourceInfoTitle: String
    let sourceInfoDetail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if shouldShowTrendChart {
                TokenMeteringDashboardPanel(
                    title: trendTitle,
                    subtitle: trendSubtitle
                ) {
                    TokenMeteringDashboardChartPlaceholder(tint: .teal)
                        .frame(height: 160)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                TokenMeteringDashboardLoadingDistributionPanel(
                    title: aiToolTitle,
                    subtitle: aiToolSubtitle,
                    infoTitle: aiToolInfoTitle,
                    infoDetail: aiToolInfoDetail,
                    tint: .teal
                )

                TokenMeteringDashboardLoadingDistributionPanel(
                    title: workflowTitle,
                    subtitle: workflowSubtitle,
                    infoTitle: workflowInfoTitle,
                    infoDetail: workflowInfoDetail,
                    tint: .blue
                )
            }

            HStack(alignment: .top, spacing: 14) {
                TokenMeteringDashboardLoadingDistributionPanel(
                    title: stageTitle,
                    subtitle: stageSubtitle,
                    infoTitle: stageInfoTitle,
                    infoDetail: stageInfoDetail,
                    tint: .purple
                )

                TokenMeteringDashboardLoadingDistributionPanel(
                    title: sourceTitle,
                    subtitle: sourceSubtitle,
                    infoTitle: sourceInfoTitle,
                    infoDetail: sourceInfoDetail,
                    tint: .orange
                )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct TokenMeteringDashboardLoadingDistributionPanel: View {
    let title: String
    let subtitle: String
    let infoTitle: String
    let infoDetail: String
    let tint: Color

    var body: some View {
        TokenMeteringDashboardPanel(
            title: title,
            subtitle: subtitle,
            infoTitle: infoTitle,
            infoDetail: infoDetail
        ) {
            TokenMeteringDashboardChartPlaceholder(tint: tint)
                .frame(height: 160)
        }
    }
}
