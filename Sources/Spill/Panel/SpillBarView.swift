import SwiftUI

struct SpillBarView: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var scanner: AXMenuBarItemScanner
    let dismissAction: () -> Void

    private var displayItems: [MenuBarItemSnapshot] {
        settings.displayMode.items(from: scanner, settings: settings)
    }

    var body: some View {
        detectedSection
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            Capsule()
                .fill(.primary.opacity(0.14))
                .frame(width: 42, height: 3)
                .padding(.top, 3)
        }
    }

    private var detectedSection: some View {
        Group {
            if !AccessibilityPermission.isTrusted {
                statusContent(systemImage: "lock.fill", title: "Accessibility Required")
            } else if scanner.isScanning && displayItems.isEmpty {
                scanningContent
            } else if displayItems.isEmpty {
                statusContent(systemImage: "magnifyingglass", title: emptyStateTitle)
            } else {
                detectedItemsContent
            }
        }
    }

    private var emptyStateTitle: String {
        switch settings.displayMode {
        case .selectedItems:
            return "No Selected Items"
        case .notchCandidates, .allDetected:
            return "No Items Detected"
        }
    }

    private var detectedItemsContent: some View {
        HStack(spacing: 9) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(itemGroups) { group in
                        SpillItemGroup(group: group, iconSpacing: settings.iconSpacing) { item in
                            if scanner.pressItem(withID: item.id) {
                                dismissAction()
                            }
                        } helpText: { item in
                            helpText(for: item)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            .frame(maxWidth: .infinity)

            if settings.showCountBadge {
                countBadge(displayItems.count)
            }
        }
    }

    private var itemGroups: [SpillItemGroupModel] {
        let systemItems = displayItems.filter(isSystemStatusItem)
        let appItems = displayItems.filter { !isSystemStatusItem($0) }

        guard !appItems.isEmpty, !systemItems.isEmpty else {
            return [
                SpillItemGroupModel(
                    kind: systemItems.isEmpty ? .apps : .system,
                    items: displayItems
                )
            ]
        }

        return [
            SpillItemGroupModel(kind: .apps, items: appItems),
            SpillItemGroupModel(kind: .system, items: systemItems)
        ]
    }

    private func isSystemStatusItem(_ item: MenuBarItemSnapshot) -> Bool {
        guard let bundleIdentifier = item.bundleIdentifier else {
            return false
        }

        return bundleIdentifier == "com.apple.systemuiserver"
            || bundleIdentifier == "com.apple.controlcenter"
            || bundleIdentifier.hasPrefix("com.apple.")
    }

    private var scanningContent: some View {
        HStack(spacing: 9) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.72)

            Text("Scanning")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }

    private func statusContent(systemImage: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }

    private func countBadge(_ count: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(.primary.opacity(0.07), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.primary.opacity(0.08), lineWidth: 0.8)
        )
        .accessibilityLabel("\(count) detected menu bar items")
    }

    private func helpText(for item: MenuBarItemSnapshot) -> String {
        var parts = [item.displayTitle, item.ownerName]

        if item.isNotchCandidate {
            parts.append("near notch estimate")
        }

        return parts.joined(separator: " - ")
    }
}

private struct SpillItemGroupModel: Identifiable {
    let kind: SpillItemGroupKind
    let items: [MenuBarItemSnapshot]

    var id: SpillItemGroupKind { kind }
}

private enum SpillItemGroupKind {
    case apps
    case system

    var symbolName: String {
        switch self {
        case .apps:
            return "app.dashed"
        case .system:
            return "switch.2"
        }
    }

    var accentOpacity: Double {
        switch self {
        case .apps:
            return 0.06
        case .system:
            return 0.085
        }
    }
}

private struct SpillItemGroup: View {
    let group: SpillItemGroupModel
    let iconSpacing: Double
    let action: (MenuBarItemSnapshot) -> Void
    let helpText: (MenuBarItemSnapshot) -> String

    var body: some View {
        HStack(spacing: max(CGFloat(iconSpacing), 6)) {
            groupGlyph

            ForEach(group.items) { item in
                SpillItemButton(item: item) {
                    action(item)
                }
                .disabled(!item.canPress)
                .help(helpText(item))
                .accessibilityLabel(item.displayTitle)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.primary.opacity(group.kind.accentOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 0.8)
        )
    }

    private var groupGlyph: some View {
        Image(systemName: group.kind.symbolName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 16, height: 34)
            .accessibilityHidden(true)
    }
}

private struct SpillItemButton: View {
    let item: MenuBarItemSnapshot
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(borderColor, lineWidth: item.isNotchCandidate ? 1.4 : 0.8)
                    )

                icon

                if item.isNotchCandidate {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 14, height: 3)
                        .padding(.bottom, 3)
                }
            }
            .frame(width: 38, height: 38)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .onHover { isHovered = $0 }
    }

    private var icon: some View {
        Group {
            if let image = item.iconImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Text(item.shortLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
            }
        }
    }

    private var backgroundColor: Color {
        if isHovered {
            return .primary.opacity(0.13)
        }

        return .primary.opacity(0.065)
    }

    private var borderColor: Color {
        if item.isNotchCandidate {
            return Color.accentColor.opacity(isHovered ? 0.95 : 0.7)
        }

        return .primary.opacity(isHovered ? 0.16 : 0.08)
    }
}
