import SwiftUI

/// Small uppercase capsule for header state such as Beta or sync mode.
struct TokenMeteringDashboardStatusBadge: View {
    let text: String
    let tint: Color
    var showsDot = false

    var body: some View {
        HStack(spacing: 4) {
            if showsDot {
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
            }
            Text(text.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(0.8)
        }
        .foregroundStyle(tint.opacity(0.85))
        .padding(.horizontal, 6)
        .frame(height: 17)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.15), lineWidth: 0.5)
        }
    }
}
