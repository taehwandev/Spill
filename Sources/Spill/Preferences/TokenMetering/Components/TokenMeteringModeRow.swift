import SwiftUI

struct TokenMeteringModeRow: View {
    let mode: TokenMeteringModeStatus

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: mode.isActive ? "checkmark.circle.fill" : "lock.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(mode.isActive ? .green : .secondary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(mode.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(mode.state)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(mode.isActive ? .green : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(mode.isActive ? Color.green.opacity(0.12) : Color.primary.opacity(0.06))
                        )
                }

                Text(mode.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}
