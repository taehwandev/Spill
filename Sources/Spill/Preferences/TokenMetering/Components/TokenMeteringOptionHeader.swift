import SwiftUI

struct TokenMeteringOptionHeader: View {
    let title: String
    let state: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)

            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)

            Text(state)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.12))
                )
        }
    }
}
