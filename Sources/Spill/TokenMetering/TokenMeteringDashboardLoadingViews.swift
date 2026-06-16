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

struct TokenMeteringDashboardChartPlaceholder: View {
    let tint: Color

    private let ratios: [CGFloat] = [0.84, 0.62, 0.76, 0.48, 0.68]

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(Array(ratios.enumerated()), id: \.offset) { index, ratio in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TokenMeteringDashboardPlaceholderCapsule(
                            widthRatio: index.isMultiple(of: 2) ? 0.34 : 0.46,
                            height: 10
                        )
                        Spacer(minLength: 8)
                        TokenMeteringDashboardPlaceholderCapsule(widthRatio: 0.28, height: 9)
                            .frame(width: 74)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [tint.opacity(0.5), tint.opacity(0.22)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: Swift.max(CGFloat(10), geometry.size.width * ratio))
                        }
                    }
                    .frame(height: 9)
                }
            }
        }
    }
}

struct TokenMeteringDashboardCompactLoadingRows: View {
    private let ratios: [CGFloat] = [0.72, 0.54, 0.66, 0.46]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(ratios.enumerated()), id: \.offset) { index, ratio in
                HStack(spacing: 8) {
                    TokenMeteringDashboardPlaceholderCapsule(widthRatio: ratio, height: 10)
                    Spacer(minLength: 4)
                    TokenMeteringDashboardPlaceholderCapsule(widthRatio: 0.56, height: 9)
                        .frame(width: index.isMultiple(of: 2) ? 58 : 46)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct TokenMeteringDashboardLoadingSessionRows: View {
    let runTitle: String
    let eventsTitle: String
    let tokensTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                TokenMeteringDashboardTableHeader(runTitle)
                TokenMeteringDashboardTableHeader(eventsTitle)
                    .frame(width: 150, alignment: .leading)
                TokenMeteringDashboardTableHeader(tokensTitle)
                    .frame(width: 96, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            ForEach(0..<5, id: \.self) { index in
                TokenMeteringDashboardLoadingSessionRow(index: index)
                    .padding(.top, 6)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct TokenMeteringDashboardLoadingSessionRow: View {
    let index: Int

    private let primaryWidths: [CGFloat] = [0.52, 0.64, 0.46, 0.58, 0.42]
    private let secondaryWidths: [CGFloat] = [0.28, 0.36, 0.32, 0.44, 0.30]

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                TokenMeteringDashboardPlaceholderCapsule(
                    widthRatio: primaryWidths[index % primaryWidths.count],
                    height: 12
                )
                TokenMeteringDashboardPlaceholderCapsule(
                    widthRatio: secondaryWidths[index % secondaryWidths.count],
                    height: 9
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TokenMeteringDashboardPlaceholderCapsule(widthRatio: 0.72, height: 10)
                .frame(width: 150, alignment: .leading)
            TokenMeteringDashboardPlaceholderCapsule(widthRatio: 0.68, height: 11)
                .frame(width: 96, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }
}
