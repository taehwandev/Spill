import AppKit
import SwiftUI

struct SpillBarView: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var scanner: AXMenuBarItemScanner
    @ObservedObject var statusStore: SystemStatusStore
    @ObservedObject var aiStatusStore: AIStatusStore
    @ObservedObject var windowActionStore: WindowActionStore
    @ObservedObject var sleepGuard: SleepGuardController
    let dismissAction: () -> Void
    @State private var actionFeedback: SpillActionFeedback?
    @State private var statusDetailTarget: SpillStatusDetailTarget?

    private var displayItems: [MenuBarItemSnapshot] {
        settings.displayMode.items(from: scanner, settings: settings)
    }

    private var pinnedItems: [MenuBarItemSnapshot] {
        scanner.items.filter { settings.selectedItemKeys.contains($0.stableKey) }
    }

    private var displayActionItems: [MenuBarItemSnapshot] {
        displayItems.filter { !settings.selectedItemKeys.contains($0.stableKey) }
    }

    private var pinnedActionItems: [SpillDisplayedActionItem] {
        pinnedItems.map(displayedActionItem)
    }

    private var displayedActionItems: [SpillDisplayedActionItem] {
        displayActionItems.map(displayedActionItem)
    }

    private var actionItems: [SpillDisplayedActionItem] {
        pinnedActionItems + displayedActionItems
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
        VStack(spacing: 8) {
            header
            if !visibleStatusModules.isEmpty {
                statusSection
            }
            aiSection
            actionsSection
            footer
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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

                Text(headerSubtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(actionFeedback?.tint ?? .secondary)
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

    private var headerSubtitle: String {
        if let actionFeedback {
            return actionFeedback.message
        }

        return panelState.subtitle(count: displayItems.count, pinnedCount: pinnedItems.count)
    }

    private var statusSection: some View {
        VStack(spacing: 5) {
            sectionHeader("STATUS", symbolName: "waveform.path.ecg")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ],
                spacing: 6
            ) {
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
            detailButton(
                target: .system(module),
                title: module.meterTitle,
                value: status.value,
                subtitle: status.subtitle,
                symbolName: module.symbolName,
                tint: statusTint(for: status.state)
            )
            .help(statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle))
            .accessibilityLabel(statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle))
        case .memory:
            let status = statusStore.memory
            detailButton(
                target: .system(module),
                title: module.meterTitle,
                value: status.value,
                subtitle: status.subtitle,
                symbolName: module.symbolName,
                tint: statusTint(for: status.state)
            )
            .help(statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle))
            .accessibilityLabel(statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle))
        case .gpu:
            let status = statusStore.gpu
            detailButton(
                target: .system(module),
                title: module.meterTitle,
                value: status.value,
                subtitle: status.subtitle,
                symbolName: module.symbolName,
                tint: statusTint(for: status.state)
            )
            .help(statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle))
            .accessibilityLabel(statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle))
        case .network:
            let status = statusStore.network
            detailButton(
                target: .system(module),
                title: module.meterTitle,
                value: status.value,
                subtitle: status.subtitle,
                symbolName: module.symbolName,
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

    private var aiSection: some View {
        VStack(spacing: 5) {
            sectionHeader("AI", symbolName: "sparkles")

            HStack(spacing: 6) {
                ForEach(aiStatusStore.statuses) { status in
                    detailButton(
                        target: .ai(status.kind),
                        title: status.title,
                        value: status.value,
                        subtitle: status.subtitle,
                        symbolName: status.symbolName,
                        tint: statusTint(for: status.state)
                    )
                    .help(statusHelpText(title: status.title, value: status.value, subtitle: status.subtitle))
                    .accessibilityLabel(statusHelpText(title: status.title, value: status.value, subtitle: status.subtitle))
                }
            }
        }
    }

    private func detailButton(
        target: SpillStatusDetailTarget,
        title: String,
        value: String,
        subtitle: String?,
        symbolName: String,
        tint: Color
    ) -> some View {
        Button {
            statusDetailTarget = target
        } label: {
            compactStatusPill(
                title: title,
                value: value,
                subtitle: subtitle,
                symbolName: symbolName,
                tint: tint
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: detailBinding(for: target), arrowEdge: .top) {
            statusDetailPopover(for: target)
        }
    }

    private func compactStatusPill(
        title: String,
        value: String,
        subtitle: String?,
        symbolName: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbolName)
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 11, height: 11)

                Text(title)
                    .font(.system(size: 8.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 2)

                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .monospacedDigit()
            }

            Text(subtitleText(subtitle))
                .font(.system(size: 8.2, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .monospacedDigit()
                .foregroundStyle(tint.opacity(0.72))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .frame(height: 42)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.1), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.2), lineWidth: 0.8)
        }
    }

    @ViewBuilder
    private func statusDetailPopover(for target: SpillStatusDetailTarget) -> some View {
        switch target {
        case let .system(module):
            SpillStatusDetailPopover(
                title: module.title,
                symbolName: module.symbolName,
                tint: statusTint(for: state(for: module)),
                rows: detailRows(for: module),
                showsInMenuBar: menuBarStatusBinding(for: module)
            )
        case let .ai(kind):
            let status = aiStatus(for: kind)
            SpillStatusDetailPopover(
                title: status.title,
                symbolName: status.symbolName,
                tint: statusTint(for: status.state),
                rows: detailRows(for: status),
                showsInMenuBar: nil
            )
        }
    }

    private func detailBinding(for target: SpillStatusDetailTarget) -> Binding<Bool> {
        Binding {
            statusDetailTarget == target
        } set: { isPresented in
            if !isPresented, statusDetailTarget == target {
                statusDetailTarget = nil
            }
        }
    }

    private func menuBarStatusBinding(for module: SpillStatusModule) -> Binding<Bool>? {
        guard let item = menuBarItem(for: module),
              SpillMenuBarStatusItem.glanceSupported.contains(item)
        else {
            return nil
        }

        return Binding {
            settings.isMenuBarStatusItemEnabled(item)
        } set: { isEnabled in
            settings.setMenuBarStatusItem(item, enabled: isEnabled)
        }
    }

    private func menuBarItem(for module: SpillStatusModule) -> SpillMenuBarStatusItem? {
        switch module {
        case .cpu:
            return .cpu
        case .memory:
            return .memory
        case .gpu:
            return nil
        case .network:
            return nil
        }
    }

    private func state(for module: SpillStatusModule) -> SpillStatusState {
        switch module {
        case .cpu:
            return statusStore.cpu.state
        case .memory:
            return statusStore.memory.state
        case .gpu:
            return statusStore.gpu.state
        case .network:
            return statusStore.network.state
        }
    }

    private func detailRows(for module: SpillStatusModule) -> [SpillStatusDetailRow] {
        switch module {
        case .cpu:
            let status = statusStore.cpu
            return [
                SpillStatusDetailRow(label: "Usage", value: status.value),
                SpillStatusDetailRow(label: "Available", value: percentText(status.availableRatio)),
                SpillStatusDetailRow(label: "User", value: percentText(status.userRatio)),
                SpillStatusDetailRow(label: "System", value: percentText(status.systemRatio)),
                SpillStatusDetailRow(label: "Nice", value: percentText(status.niceRatio)),
                SpillStatusDetailRow(label: "Idle", value: percentText(status.idleRatio)),
                SpillStatusDetailRow(label: "Sample", value: "\(status.activeTicks) / \(status.totalTicks) active ticks"),
                SpillStatusDetailRow(label: "State", value: status.state.detailTitle)
            ]
        case .memory:
            let status = statusStore.memory
            return [
                SpillStatusDetailRow(label: "Usage", value: status.value),
                SpillStatusDetailRow(label: "Used", value: SystemMemoryProvider.formatBytes(status.usedBytes)),
                SpillStatusDetailRow(label: "Available", value: SystemMemoryProvider.formatBytes(status.availableBytes)),
                SpillStatusDetailRow(label: "Free", value: SystemMemoryProvider.formatBytes(status.freeBytes)),
                SpillStatusDetailRow(label: "Active", value: SystemMemoryProvider.formatBytes(status.activeBytes)),
                SpillStatusDetailRow(label: "Inactive", value: SystemMemoryProvider.formatBytes(status.inactiveBytes)),
                SpillStatusDetailRow(label: "Wired", value: SystemMemoryProvider.formatBytes(status.wiredBytes)),
                SpillStatusDetailRow(label: "Compressed", value: SystemMemoryProvider.formatBytes(status.compressedBytes)),
                SpillStatusDetailRow(label: "Total", value: SystemMemoryProvider.formatBytes(status.totalBytes))
            ]
        case .gpu:
            let status = statusStore.gpu
            let unifiedCount = status.devices.filter(\.hasUnifiedMemory).count
            let lowPowerCount = status.devices.filter(\.isLowPower).count
            let headlessCount = status.devices.filter(\.isHeadless).count
            var rows = [
                SpillStatusDetailRow(label: "Available", value: "\(status.availableDeviceCount) / \(status.totalDeviceCount)"),
                SpillStatusDetailRow(label: "Budget", value: status.totalRecommendedMaxWorkingSetBytes > 0 ? SystemMemoryProvider.formatBytes(status.totalRecommendedMaxWorkingSetBytes) : "N/A"),
                SpillStatusDetailRow(label: "Unified", value: "\(unifiedCount)"),
                SpillStatusDetailRow(label: "Low Power", value: "\(lowPowerCount)"),
                SpillStatusDetailRow(label: "Headless", value: "\(headlessCount)")
            ]
            rows.append(contentsOf: status.devices.prefix(3).map { device in
                let traits = [
                    device.hasUnifiedMemory ? "Unified" : nil,
                    device.isLowPower ? "Low Power" : nil,
                    device.isRemovable ? "Removable" : nil,
                    device.isHeadless ? "Headless" : nil
                ].compactMap { $0 }
                let suffix = traits.isEmpty ? "" : " - \(traits.joined(separator: ", "))"
                return SpillStatusDetailRow(
                    label: device.name,
                    value: "\(device.memoryLabel ?? "N/A")\(suffix)"
                )
            })
            return rows
        case .network:
            let status = statusStore.network
            return [
                SpillStatusDetailRow(label: "Route", value: status.value),
                SpillStatusDetailRow(label: "Reachable", value: boolText(status.isReachable)),
                SpillStatusDetailRow(label: "Connection Required", value: boolText(status.connectionRequired)),
                SpillStatusDetailRow(label: "Auto Connect", value: boolText(status.canConnectAutomatically)),
                SpillStatusDetailRow(label: "Intervention", value: boolText(status.interventionRequired))
            ]
        }
    }

    private func detailRows(for status: LocalAIToolStatus) -> [SpillStatusDetailRow] {
        [
            SpillStatusDetailRow(label: "Status", value: status.value),
            SpillStatusDetailRow(label: "Detail", value: status.subtitle ?? "N/A"),
            SpillStatusDetailRow(label: "Menu Bar", value: aiMenuBarSummary)
        ]
    }

    private func aiStatus(for kind: LocalAIToolKind) -> LocalAIToolStatus {
        aiStatusStore.statuses.first { $0.kind == kind } ?? LocalAIToolStatus(
            kind: kind,
            value: "N/A",
            subtitle: nil,
            state: .unavailable
        )
    }

    private var aiMenuBarSummary: String {
        let summary = MenuBarStatusSummary.make(
            enabledItems: [.ai],
            cpu: statusStore.cpu,
            memory: statusStore.memory,
            gpu: statusStore.gpu,
            network: statusStore.network,
            aiStatuses: aiStatusStore.statuses
        )
        return summary.title
    }

    private func boolText(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private func percentText(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    private func subtitleText(_ subtitle: String?) -> String {
        guard let subtitle, !subtitle.isEmpty else {
            return "No detail"
        }

        return subtitle
    }

    private func performWindowAction(_ action: SpillAction) {
        let result = windowActionStore.perform(action)
        actionFeedback = SpillActionFeedback(result: result, title: action.title)
    }

    private func windowHelpText(for action: SpillAction) -> String {
        var parts = [action.title]

        if let subtitle = action.subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }

        if let disabledReason = action.state.disabledReason {
            parts.append(disabledReason)
        }

        return parts.joined(separator: " - ")
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionHeader("ACTIONS", symbolName: "square.grid.2x2")

            Group {
                if !AccessibilityPermission.isTrusted {
                    inlineState(symbolName: "lock.fill", title: "Accessibility Required")
                } else if scanner.isScanning && displayItems.isEmpty {
                    scanningState
                } else if actionItems.isEmpty && windowActionStore.actions.isEmpty {
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
                ForEach(windowActionStore.actions) { action in
                    WindowActionButton(action: action) {
                        performWindowAction(action)
                    }
                    .help(windowHelpText(for: action))
                    .accessibilityLabel(action.title)
                }

                ForEach(actionItems) { item in
                    SpillActionButton(
                        action: item.action,
                        isPinned: item.isPinned,
                        togglePinned: { togglePinned(item.sourceItem) },
                        perform: { perform(item) }
                    )
                    .help(helpText(for: item))
                    .accessibilityLabel(item.action.title)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func displayedActionItem(from item: MenuBarItemSnapshot) -> SpillDisplayedActionItem {
        SpillDisplayedActionItem(
            sourceItem: item,
            action: MenuBarActionAdapter.action(from: item),
            isPinned: settings.selectedItemKeys.contains(item.stableKey)
        )
    }

    private func togglePinned(_ item: MenuBarItemSnapshot) {
        let isPinned = settings.selectedItemKeys.contains(item.stableKey)
        settings.setItem(item, selected: !isPinned)
        actionFeedback = SpillActionFeedback(
            result: .success,
            title: item.displayTitle,
            overrideMessage: isPinned ? "Unpinned \(item.displayTitle)" : "Pinned \(item.displayTitle)"
        )
    }

    private func perform(_ item: SpillDisplayedActionItem) {
        let result = performMenuBarAction(item.action)
        actionFeedback = SpillActionFeedback(result: result, title: item.action.title)

        if result == .success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                dismissAction()
            }
        }
    }

    private func performMenuBarAction(_ action: SpillAction) -> SpillActionResult {
        guard action.state.isEnabled else {
            return .failed(message: action.state.disabledReason ?? "Action disabled")
        }

        if let snapshotID = MenuBarActionAdapter.sourceSnapshotID(for: action),
           scanner.pressItem(withID: snapshotID)
        {
            return .success
        }

        if activateApp(bundleIdentifier: MenuBarActionAdapter.sourceBundleIdentifier(for: action)) {
            return .success
        }

        return .failed(message: "Action unavailable")
    }

    private func activateApp(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else {
            return false
        }

        if let runningApp = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first
        {
            return runningApp.activate(options: [])
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        return true
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

            sleepGuardFooter

            if settings.showPowerFooter {
                powerFooter(status: statusStore.power)
            }

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

    private var sleepGuardFooter: some View {
        Menu {
            if sleepGuard.isActive {
                Button(role: .destructive) {
                    sleepGuard.stop()
                } label: {
                    Text("Stop Sleep Guard")
                }

                Divider()
            }

            ForEach(SleepGuardDuration.allCases) { duration in
                Button(duration.menuTitle) {
                    sleepGuard.start(
                        duration: duration,
                        keepDisplayAwake: settings.sleepGuardKeepsDisplayAwake
                    )
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sleepGuard.isActive ? "moon.fill" : "moon")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 13, height: 13)

                if sleepGuard.isActive {
                    Text(sleepGuard.remainingLabel)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .foregroundStyle(sleepGuardTint)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(sleepGuardHelpText)
        .accessibilityLabel(sleepGuardHelpText)
    }

    private var sleepGuardTint: Color {
        if sleepGuard.isActive {
            return .accentColor
        }

        if sleepGuard.errorMessage != nil {
            return .orange
        }

        return .secondary
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

    private var sleepGuardHelpText: String {
        if let errorMessage = sleepGuard.errorMessage {
            return "Sleep Guard - \(errorMessage)"
        }

        guard sleepGuard.isActive else {
            return "Sleep Guard Off"
        }

        return "Sleep Guard - \(sleepGuard.remainingLabel) remaining"
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
    let isPinned: Bool

    var id: String {
        action.id
    }
}

private enum SpillStatusDetailTarget: Equatable {
    case system(SpillStatusModule)
    case ai(LocalAIToolKind)
}

private struct SpillStatusDetailRow: Identifiable, Equatable {
    let label: String
    let value: String

    var id: String {
        label
    }
}

private struct SpillStatusDetailPopover: View {
    let title: String
    let symbolName: String
    let tint: Color
    let rows: [SpillStatusDetailRow]
    let showsInMenuBar: Binding<Bool>?

    init(
        title: String,
        symbolName: String,
        tint: Color,
        rows: [SpillStatusDetailRow],
        showsInMenuBar: Binding<Bool>?
    ) {
        self.title = title
        self.symbolName = symbolName
        self.tint = tint
        self.rows = rows
        self.showsInMenuBar = showsInMenuBar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            } icon: {
                Image(systemName: symbolName)
                    .foregroundStyle(tint)
            }

            VStack(spacing: 6) {
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        Text(row.label)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        Text(row.value)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .font(.system(size: 11, weight: .medium))
                }
            }

            if let showsInMenuBar {
                Divider()

                Toggle(isOn: showsInMenuBar) {
                    Label("Show in menu bar", systemImage: "menubar.rectangle")
                        .font(.system(size: 11, weight: .medium))
                }
                .toggleStyle(.switch)
            }
        }
        .padding(12)
        .frame(width: 244)
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

    func subtitle(count: Int, pinnedCount: Int) -> String {
        switch self {
        case .permissionRequired:
            return "Permission needed"
        case .scanning:
            return "Refreshing actions"
        case .empty:
            return pinnedCount > 0 ? "\(pinnedCount) pinned" : "No actions ready"
        case .ready:
            if pinnedCount > 0 {
                return "\(pinnedCount) pinned, \(count) ready"
            }

            return "\(count) action\(count == 1 ? "" : "s") ready"
        }
    }
}

private extension SpillStatusState {
    var detailTitle: String {
        switch self {
        case .normal:
            return "Normal"
        case .active:
            return "Active"
        case .warning:
            return "Warning"
        case .unavailable:
            return "Unavailable"
        case .refreshing:
            return "Refreshing"
        }
    }
}

private struct WindowActionButton: View {
    let action: SpillAction
    let perform: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: perform) {
            Image(systemName: action.symbolName ?? "macwindow")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: 30, height: 28)
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

private struct SpillActionButton: View {
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

private struct SpillActionFeedback: Equatable {
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
