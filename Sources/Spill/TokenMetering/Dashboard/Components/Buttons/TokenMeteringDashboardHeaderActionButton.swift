import SwiftUI

/// Square icon button used in the dashboard header toolbar.
struct TokenMeteringDashboardHeaderActionButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let helpText: String
    var isEnabled = true
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(HeaderActionButtonStyle(isEnabled: isEnabled, isActive: isActive))
        .disabled(!isEnabled)
        .help(helpText)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(helpText))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct HeaderActionButtonStyle: ButtonStyle {
    let isEnabled: Bool
    var isActive = false
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(
                isActive
                    ? AnyShapeStyle(.tint)
                    : AnyShapeStyle(isEnabled ? Color.primary.opacity(0.72) : Color.primary.opacity(0.28))
            )
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? Color.primary.opacity(0.12)
                            : (isHovered && isEnabled ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isHovered && isEnabled
                            ? Color.primary.opacity(0.14)
                            : Color.primary.opacity(0.08),
                        lineWidth: 0.5
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
