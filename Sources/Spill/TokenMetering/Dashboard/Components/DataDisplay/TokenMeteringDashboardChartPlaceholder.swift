import SwiftUI

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
