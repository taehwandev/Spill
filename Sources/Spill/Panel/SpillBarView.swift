import SwiftUI

struct SpillBarView: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var scanner: AXMenuBarItemScanner
    @ObservedObject var statusStore: SystemStatusStore
    let dismissAction: () -> Void

    private var displayItems: [MenuBarItemSnapshot] {
        settings.displayMode.items(from: scanner, settings: settings)
    }

    private var displayedActionItems: [SpillDisplayedActionItem] {
        displayItems.map { item in
            SpillDisplayedActionItem(
                sourceItem: item,
                action: MenuBarActionAdapter.action(from: item)
            )
        }
    }

    private var visibleStatusModules: [SpillStatusModule] {
        settings.statusModuleOrder.filter { settings.isStatusModuleEnabled($0) }
    }

    private var panelState: SpillPanelState {
        if !AccessibilityPermission.isTrusted {
            return .permissionRequired
        }

        if scanner.isScanning {
            return .scanning
        }

        if displayItems.isEmpty {
            return .empty
        }

        return .ready
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            if !visibleStatusModules.isEmpty {
                statusSection
            }
            actionsSection
            footer
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.accentColor.opacity(0.18))

                Image(systemName: panelState.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(panelState.tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Spill Flow")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(panelState.subtitle(count: displayItems.count))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            statusDot
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(panelState.tint)
            .frame(width: 8, height: 8)
            .overlay {
                Circle()
                    .stroke(panelState.tint.opacity(0.22), lineWidth: 5)
            }
            .accessibilityLabel(panelState.accessibilityLabel)
    }

    private var statusSection: some View {
        VStack(spacing: 9) {
            sectionHeader("STATUS", symbolName: "waveform.path.ecg")

            VStack(spacing: 8) {
                ForEach(visibleStatusModules) { module in
                    statusMeter(for: module)
                }
            }
        }
    }

    @ViewBuilder
    private func statusMeter(for module: SpillStatusModule) -> some View {
        switch module {
        case .cpu:
            let status = statusStore.cpu
            statusMeter(
                title: module.meterTitle,
                value: status.value,
                progress: status.usageRatio,
                tint: statusTint(for: status.state)
            )
            .help(statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle))
            .accessibilityLabel(statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle))
        case .memory:
            let status = statusStore.memory
            statusMeter(
                title: module.meterTitle,
                value: status.value,
                progress: status.usageRatio,
                tint: statusTint(for: status.state)
            )
            .help(statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle))
            .accessibilityLabel(statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle))
        }
    }

    private func statusTint(for state: SpillStatusState) -> Color {
        switch state {
        case .normal:
            return .green
        case .active:
            return .accentColor
        case .warning:
            return .orange
        case .unavailable:
            return .secondary
        case .refreshing:
            return .accentColor
        }
    }

    private func sectionHeader(_ title: String, symbolName: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func statusMeter(title: String, value: String, progress: Double, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(value)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.82))
                    .lineLimit(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.primary.opacity(0.08))

                    Capsule()
                        .fill(tint.opacity(0.86))
                        .frame(width: max(4, proxy.size.width * progress.clamped(to: 0...1)))
                }
            }
            .frame(height: 5)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionHeader("ACTIONS", symbolName: "square.grid.2x2")

            Group {
                if !AccessibilityPermission.isTrusted {
                    inlineState(symbolName: "lock.fill", title: "Accessibility Required")
                } else if scanner.isScanning && displayItems.isEmpty {
                    scanningState
                } else if displayItems.isEmpty {
                    inlineState(symbolName: "magnifyingglass", title: emptyStateTitle)
                } else {
                    actionScroller
                }
            }
            .frame(height: 38)
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

    private var actionScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: max(CGFloat(settings.iconSpacing), 7)) {
                ForEach(displayedActionItems) { item in
                    SpillActionButton(action: item.action) {
                        if let snapshotID = MenuBarActionAdapter.sourceSnapshotID(for: item.action),
                           scanner.pressItem(withID: snapshotID)
                        {
                            dismissAction()
                        }
                    }
                    .disabled(!item.action.state.isEnabled)
                    .help(helpText(for: item))
                    .accessibilityLabel(item.action.title)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private var scanningState: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.68)

            Text("Scanning")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func inlineState(symbolName: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            footerItem(symbolName: AccessibilityPermission.isTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .foregroundStyle(AccessibilityPermission.isTrusted ? .green : .orange)

            footerItem(symbolName: scanner.isScanning ? "arrow.triangle.2.circlepath" : "bolt.horizontal.fill")
                .foregroundStyle(scanner.isScanning ? Color.accentColor : Color.secondary)

            powerFooter(status: statusStore.power)

            if settings.showCountBadge {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("\(displayItems.count)")
                        .monospacedDigit()
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(shortTime)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 11)
        .frame(height: 28)
        .background(.primary.opacity(0.06), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.08), lineWidth: 0.8)
        }
    }

    private func footerItem(symbolName: String) -> some View {
        Image(systemName: symbolName)
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 13, height: 13)
    }

    private func powerFooter(status: SystemPowerStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbolName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 13, height: 13)

            Text(status.value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(statusTint(for: status.state))
        .help(powerHelpText(for: status))
        .accessibilityLabel(powerHelpText(for: status))
    }

    private var shortTime: String {
        Self.timeFormatter.string(from: Date())
    }

    private func powerHelpText(for status: SystemPowerStatus) -> String {
        var parts = ["Power", status.value]

        if let subtitle = status.subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }

        return parts.joined(separator: " - ")
    }

    private func statusHelpText(title: String, value: String, subtitle: String?) -> String {
        var parts = [title, value]

        if let subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }

        return parts.joined(separator: " - ")
    }

    private func helpText(for item: SpillDisplayedActionItem) -> String {
        var parts = [item.action.title]

        if let subtitle = item.action.subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }

        if item.sourceItem.isNotchCandidate {
            parts.append("near notch estimate")
        }

        if let disabledReason = item.action.state.disabledReason {
            parts.append(disabledReason)
        }

        return parts.joined(separator: " - ")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

private struct SpillDisplayedActionItem: Identifiable {
    let sourceItem: MenuBarItemSnapshot
    let action: SpillAction

    var id: String {
        action.id
    }
}

private enum SpillPanelState {
    case permissionRequired
    case scanning
    case empty
    case ready

    var symbolName: String {
        switch self {
        case .permissionRequired:
            return "lock.fill"
        case .scanning:
            return "arrow.triangle.2.circlepath"
        case .empty:
            return "tray"
        case .ready:
            return "drop.fill"
        }
    }

    var tint: Color {
        switch self {
        case .permissionRequired:
            return .orange
        case .scanning:
            return .accentColor
        case .empty:
            return .secondary
        case .ready:
            return .green
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .permissionRequired:
            return "Accessibility required"
        case .scanning:
            return "Scanning"
        case .empty:
            return "No actions ready"
        case .ready:
            return "Ready"
        }
    }

    func subtitle(count: Int) -> String {
        switch self {
        case .permissionRequired:
            return "Permission needed"
        case .scanning:
            return "Refreshing actions"
        case .empty:
            return "No actions ready"
        case .ready:
            return "\(count) action\(count == 1 ? "" : "s") ready"
        }
    }
}

private struct SpillActionButton: View {
    let action: SpillAction
    let perform: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
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
        .opacity(isEnabled ? 1 : 0.44)
        .onHover { isHovered = $0 }
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
                    .foregroundStyle(isEnabled ? .primary : .secondary)
            }
        }
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

private extension SpillAction {
    var shortLabel: String {
        let source = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = source.first else {
            return "?"
        }

        return String(first).uppercased()
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
