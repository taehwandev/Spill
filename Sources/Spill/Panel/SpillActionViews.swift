import AppKit
import SwiftUI

struct SpillDisplayedActionItem: Identifiable {
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
    let perform: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: perform) {
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    Image(systemName: action.symbolName ?? "macwindow")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 14, height: 12)

                    Text(labelText)
                        .font(.system(size: 8.3, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Text(shortcutText)
                    .font(.system(size: 7.4, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(foregroundColor)
            .frame(width: 61, height: 38)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!action.state.isEnabled)
        .opacity(action.state.isEnabled ? 1 : 0.42)
        .onHover { isHovered = $0 }
    }

    private var labelText: String {
        switch action.kind {
        case .window(.leftHalf):
            return "Left"
        case .window(.rightHalf):
            return "Right"
        case .window(.center):
            return "Center"
        case .window(.maximize):
            return "Max"
        case .window(.nextDisplay):
            return "Display"
        case .window(.restore):
            return "Restore"
        case .menuBarItem, .app, .command:
            return action.title
        }
    }

    private var shortcutText: String {
        guard case .window = action.kind else {
            return ""
        }

        return shortcutKey.shortcutLabel
    }

    private var foregroundColor: Color {
        action.state.isEnabled ? .primary : .secondary
    }

    private var backgroundColor: Color {
        isHovered ? .primary.opacity(0.13) : .primary.opacity(0.065)
    }

    private var borderColor: Color {
        isHovered ? .primary.opacity(0.18) : .primary.opacity(0.08)
    }
}

struct SpillActionButton: View {
    let action: SpillAction
    let isPinned: Bool
    let togglePinned: () -> Void
    let perform: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: perform) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(backgroundColor)
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(borderColor, lineWidth: action.role == .primary ? 1.2 : 0.8)
                        }

                    icon

                    if action.role == .primary {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 5, height: 5)
                            .padding(5)
                    }
                }
                .frame(width: 36, height: 36)
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canPerform)
            .opacity(canPerform ? 1 : 0.44)
            .onHover { isHovered = $0 }

            Button(action: togglePinned) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                    .frame(width: 15, height: 15)
                    .background(.regularMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.primary.opacity(0.12), lineWidth: 0.6)
                    }
            }
            .buttonStyle(.plain)
            .help(isPinned ? "Unpin" : "Pin")
        }
        .frame(width: 39, height: 38)
    }

    private var icon: some View {
        Group {
            if let image = iconImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Text(action.shortLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(canPerform ? .primary : .secondary)
            }
        }
    }

    private var canPerform: Bool {
        action.state.isEnabled
    }

    private var iconImage: NSImage? {
        guard let iconData = action.iconData else {
            return nil
        }

        return NSImage(data: iconData)
    }

    private var backgroundColor: Color {
        if isHovered {
            return .primary.opacity(0.13)
        }

        return .primary.opacity(0.065)
    }

    private var borderColor: Color {
        if action.role == .primary {
            return Color.accentColor.opacity(isHovered ? 0.95 : 0.7)
        }

        return .primary.opacity(isHovered ? 0.16 : 0.08)
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
            return "Opened \(title)"
        case .unavailable:
            return "\(title) unavailable"
        case let .permissionRequired(permission):
            return "\(permission) permission required"
        case .unsupported:
            return "\(title) unsupported"
        case let .failed(message):
            return message
        }
    }

    var tint: Color {
        switch result {
        case .success:
            return .green
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
