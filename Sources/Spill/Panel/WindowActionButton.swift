import SwiftUI

struct WindowActionButton: View {
    let action: SpillAction
    let shortcutKey: WindowActionShortcutKey
    let appLanguage: SpillAppLanguage
    let perform: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: perform) {
            VStack(spacing: 3) {
                Spacer(minLength: 0)

                Image(systemName: action.symbolName ?? "macwindow")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 20, height: 16)

                Text(labelText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if shortcutKey != .off {
                    Text(shortcutText)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(Color.secondary)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(foregroundColor)
            .frame(width: 76, height: 58)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.03), radius: 1, y: 0.5)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!action.state.isEnabled)
        .opacity(action.state.isEnabled ? 1 : 0.7)
        .onHover { isHovered = $0 }
    }

    private var labelText: String {
        switch action.kind {
        case .window(.leftHalf):
            return AppL10n.windowActionTitle(.leftHalf, appLanguage: appLanguage)
        case .window(.rightHalf):
            return AppL10n.windowActionTitle(.rightHalf, appLanguage: appLanguage)
        case .window(.topHalf):
            return AppL10n.windowActionTitle(.topHalf, appLanguage: appLanguage)
        case .window(.bottomHalf):
            return AppL10n.windowActionTitle(.bottomHalf, appLanguage: appLanguage)
        case .window(.center):
            return AppL10n.windowActionTitle(.center, appLanguage: appLanguage)
        case .window(.maximize):
            return AppL10n.windowActionTitle(.maximize, appLanguage: appLanguage)
        case .window(.topLeft):
            return AppL10n.windowActionTitle(.topLeft, appLanguage: appLanguage)
        case .window(.topRight):
            return AppL10n.windowActionTitle(.topRight, appLanguage: appLanguage)
        case .window(.bottomLeft):
            return AppL10n.windowActionTitle(.bottomLeft, appLanguage: appLanguage)
        case .window(.bottomRight):
            return AppL10n.windowActionTitle(.bottomRight, appLanguage: appLanguage)
        case .window(.previousDisplay):
            return AppL10n.windowActionTitle(.previousDisplay, appLanguage: appLanguage)
        case .window(.nextDisplay):
            return AppL10n.windowActionTitle(.nextDisplay, appLanguage: appLanguage)
        case .window(.restore):
            return AppL10n.windowActionTitle(.restore, appLanguage: appLanguage)
        }
    }

    private var shortcutText: String {
        guard case let .window(kind) = action.kind else {
            return ""
        }

        return kind.shortcutLabel(for: shortcutKey)
    }

    private var foregroundColor: Color {
        action.state.isEnabled ? .primary : .secondary
    }

    private var backgroundColor: Color {
        isHovered ? .primary.opacity(0.1) : .primary.opacity(0.04)
    }

}
