import AppKit
import SwiftUI

@MainActor
struct MenuBarTriggerIconPreview: View {
    private static let appliedTriggerIconSize: CGFloat = 18

    let style: MenuBarTriggerIconStyle
    let isAnimated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !isAnimated || !style.animates)) { context in
            let phase = isAnimated ? phase(for: context.date) : 0.18

            HStack(spacing: 10) {
                Text(PreferencesL10n.text(.preview))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    triggerImage(style: style, phase: phase)
                        .frame(width: Self.appliedTriggerIconSize, height: Self.appliedTriggerIconSize)

                    Text("12:45")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                )

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func triggerImage(style: MenuBarTriggerIconStyle, phase: CGFloat) -> some View {
        Group {
            if let image = MenuBarTriggerIconRenderer.image(
                style: style,
                phase: phase,
                size: Self.appliedTriggerIconSize
            ) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
            } else {
                Image(systemName: style.symbolName(isActive: false))
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .foregroundStyle(Color.accentColor)
    }

    private func phase(for date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1))
    }
}
