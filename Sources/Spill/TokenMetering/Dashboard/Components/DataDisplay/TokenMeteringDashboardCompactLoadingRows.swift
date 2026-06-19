import SwiftUI

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
