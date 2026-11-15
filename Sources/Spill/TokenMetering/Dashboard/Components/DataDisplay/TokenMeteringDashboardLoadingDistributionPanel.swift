import SwiftUI

/// Loading stand-in for `TokenMeteringDashboardDistributionPanel`. It keeps the
/// same title, info affordance, and minimum height so the layout does not jump
/// when the first snapshot lands.
struct TokenMeteringDashboardLoadingDistributionPanel: View {
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
            TokenMeteringDashboardChartPlaceholder(
                tint: tint,
                rowCount: TokenMeteringDashboardChartPlaceholder.rowCount(fitting: placeholderHeight)
            )
            .frame(height: placeholderHeight, alignment: .top)
        }
        .accessibilityHidden(true)
    }
}
