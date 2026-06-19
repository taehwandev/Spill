import SwiftUI

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
