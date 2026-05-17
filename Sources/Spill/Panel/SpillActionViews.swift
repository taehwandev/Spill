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
    let perform: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: action.symbolName ?? "macwindow")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 20, height: 16)

                Text(labelText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(shortcutText)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(foregroundColor)
            .frame(width: 76, height: 50)
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
            return "Left"
        case .window(.rightHalf):
            return "Right"
        case .window(.topHalf):
            return "Top"
        case .window(.bottomHalf):
            return "Bottom"
        case .window(.center):
            return "Center"
        case .window(.maximize):
            return "Max"
        case .window(.topLeft):
            return "Top L"
        case .window(.topRight):
            return "Top R"
        case .window(.bottomLeft):
            return "Bot L"
        case .window(.bottomRight):
            return "Bot R"
        case .window(.previousDisplay):
            return "Disp L"
        case .window(.nextDisplay):
            return "Disp R"
        case .window(.restore):
            return "Restore"
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
                            .fill(Color.blue)
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
                    .foregroundStyle(isPinned ? .blue : .secondary)
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

        return NSImage(data: iconData)
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
