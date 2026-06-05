import AppKit
import SwiftUI

struct SpillDisplayedActionItem: Equatable, Identifiable {
    let sourceItem: MenuBarItemSnapshot
    let action: SpillAction
    let isPinned: Bool

    var id: String {
        action.id
    }
}

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
        case .menuBarItem, .app, .command:
            return action.title
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

struct SpillActionButton: View {
    let action: SpillAction
    let isPinned: Bool
    let appLanguage: SpillAppLanguage
    let togglePinned: () -> Void
    let perform: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: perform) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(backgroundColor)
                        .shadow(color: .black.opacity(0.02), radius: 1, y: 0.5)

                    icon
                }
                .frame(width: 44, height: 44)
                .overlay(alignment: .topTrailing) {
                    if action.role == .primary {
                        Circle()
                            .fill(Color.teal)
                            .frame(width: 5, height: 5)
                            .padding(5)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canPerform)
            .opacity(canPerform ? 1 : 0.44)
            .onHover { isHovered = $0 }

            Button(action: togglePinned) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isPinned ? .teal : .secondary)
                    .frame(width: 15, height: 15)
                    .background(.regularMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.primary.opacity(0.12), lineWidth: 0.6)
                    }
            }
            .buttonStyle(.plain)
            .help(isPinned
                ? AppL10n.text(.unpin, appLanguage: appLanguage)
                : AppL10n.text(.pin, appLanguage: appLanguage)
            )
        }
        .frame(width: 48, height: 48)
    }

    private var icon: some View {
        Group {
            if let image = iconImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else if let symbolName = action.symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(canPerform ? Color.primary : Color.secondary)
                    .frame(width: 27, height: 27)
            } else {
                Text(action.shortLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(canPerform ? .primary : .secondary)
            }
        }
        .frame(width: 30, height: 30, alignment: .center)
    }

    private var canPerform: Bool {
        action.state.isEnabled
    }

    private var iconImage: NSImage? {
        guard let iconData = action.iconData else {
            return nil
        }

        return MenuBarIconImageCache.shared.image(for: iconData)
    }

    private var backgroundColor: Color {
        if isHovered {
            return .primary.opacity(0.1)
        }

        return .primary.opacity(0.04)
    }

}

struct SpillActionFeedback: Equatable {
    let result: SpillActionResult
    let title: String
    let overrideMessage: String?

    init(result: SpillActionResult, title: String, overrideMessage: String? = nil) {
        self.result = result
        self.title = title
        self.overrideMessage = overrideMessage
    }

    var message: String {
        if let overrideMessage {
            return overrideMessage
        }

        switch result {
        case .success:
            return AppL10n.opened(title)
        case .unavailable:
            return AppL10n.unavailable(title)
        case let .permissionRequired(permission):
            return AppL10n.permissionRequired(permission)
        case .unsupported:
            return AppL10n.unsupported(title)
        case let .failed(message):
            return message
        }
    }

    var tint: Color {
        switch result {
        case .success:
            return .mint
        case .unavailable, .unsupported:
            return .secondary
        case .permissionRequired, .failed:
            return .orange
        }
    }
}

extension SpillAction {
    var shortLabel: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
    }
}
