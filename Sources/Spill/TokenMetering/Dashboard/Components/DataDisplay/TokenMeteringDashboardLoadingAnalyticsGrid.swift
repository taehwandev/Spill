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

            TokenMeteringDashboardLoadingDistributionPanel(
                title: aiToolTitle,
                subtitle: aiToolSubtitle,
                infoTitle: aiToolInfoTitle,
                infoDetail: aiToolInfoDetail,
                tint: .teal,
                minimumHeight: 180,
                placeholderHeight: 118
            )

            HStack(alignment: .top, spacing: 14) {
                TokenMeteringDashboardLoadingDistributionPanel(
                    title: workflowTitle,
                    subtitle: workflowSubtitle,
                    infoTitle: workflowInfoTitle,
                    infoDetail: workflowInfoDetail,
                    tint: .blue
                )

                TokenMeteringDashboardLoadingDistributionPanel(
                    title: stageTitle,
                    subtitle: stageSubtitle,
                    infoTitle: stageInfoTitle,
                    infoDetail: stageInfoDetail,
                    tint: .purple
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
    var minimumHeight: CGFloat = 260
    var placeholderHeight: CGFloat = 160

    var body: some View {
        TokenMeteringDashboardPanel(
            title: title,
            subtitle: subtitle,
            infoTitle: infoTitle,
            infoDetail: infoDetail,
            minimumHeight: minimumHeight
        ) {
            TokenMeteringDashboardChartPlaceholder(tint: tint)
                .frame(height: placeholderHeight)
        }
    }
}
