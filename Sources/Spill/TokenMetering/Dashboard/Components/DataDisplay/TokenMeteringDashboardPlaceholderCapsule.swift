import SwiftUI

struct TokenMeteringDashboardPlaceholderCapsule: View {
    let widthRatio: CGFloat
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                .fill(Color.primary.opacity(0.095))
                .frame(
                    width: Swift.max(height * 2, geometry.size.width * widthRatio),
                    height: height,
                    alignment: .leading
                )
        }
        .frame(height: height)
    }
}
