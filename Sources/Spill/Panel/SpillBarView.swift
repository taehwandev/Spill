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
        SpillPanelState.current(
            isAccessibilityTrusted: AccessibilityPermission.isTrusted,
            isScanning: scanner.isScanning,
            isEmpty: displayItems.isEmpty
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            header
            if !visibleStatusModules.isEmpty {
                statusSection
            }
            aiSection
            actionSections
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

    private func statusMeter(for module: SpillStatusModule) -> some View {
        let status = statusStore.meterSnapshot(for: module)
        let helpText = statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle)

        return detailButton(
            target: .system(module),
            title: module.meterTitle,
            value: status.value,
            subtitle: status.subtitle,
            symbolName: module.symbolName,
            tint: status.state.panelTint
        )
        .help(helpText)
        .accessibilityLabel(helpText)
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
                        tint: status.state.panelTint
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
                tint: statusStore.state(for: module).panelTint,
                rows: statusStore.detailRows(for: module),
                showsInMenuBar: menuBarStatusBinding(for: module)
            )
        case let .ai(kind):
            let status = aiStatus(for: kind)
            SpillStatusDetailPopover(
                title: status.title,
                symbolName: status.symbolName,
                tint: status.state.panelTint,
                rows: SpillStatusDetailRows.rows(for: status),
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

    private func aiStatus(for kind: LocalAIToolKind) -> LocalAIToolStatus {
        aiStatusStore.statuses.first { $0.kind == kind } ?? LocalAIToolStatus(
            kind: kind,
            value: "N/A",
            subtitle: nil,
            state: .unavailable
        )
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

    private var emptyStateTitle: String {
        switch settings.displayMode {
        case .selectedItems:
            return "No Selected Items"
        case .notchCandidates, .allDetected:
            return "No Items Detected"
        }
    }

    private var actionSections: some View {
        VStack(alignment: .leading, spacing: 7) {
            windowActionsSection
            menuBarActionsSection
        }
    }

    private var windowActionsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionHeader("WINDOWS", symbolName: "macwindow")

            if windowActionStore.actions.isEmpty {
                inlineState(symbolName: "macwindow", title: "No Focused Window")
                    .frame(height: 38)
            } else {
                windowActionScroller
            }
        }
    }

    private var menuBarActionsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionHeader("MENU BAR", symbolName: "menubar.rectangle")

            Group {
                if !AccessibilityPermission.isTrusted {
                    inlineState(symbolName: "lock.fill", title: "Accessibility Required")
                } else if scanner.isScanning && displayItems.isEmpty {
                    scanningState
                } else if actionItems.isEmpty {
                    inlineState(symbolName: "magnifyingglass", title: emptyStateTitle)
                } else {
                    menuBarActionScroller
                }
            }
            .frame(height: 38)
        }
    }

    private var windowActionScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(windowActionStore.actions) { action in
                    WindowActionButton(action: action) {
                        performWindowAction(action)
                    }
                    .help(windowHelpText(for: action))
                    .accessibilityLabel(action.title)
                }
            }
            .padding(.horizontal, 1)
        }
        .frame(height: 38)
    }

    private var menuBarActionScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: max(CGFloat(settings.iconSpacing), 7)) {
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
        let result = MenuBarActionExecutor(scanner: scanner).perform(item.action)
        actionFeedback = SpillActionFeedback(result: result, title: item.action.title)

        if result == .success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                dismissAction()
            }
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
        SpillFooterView(
            isAccessibilityTrusted: AccessibilityPermission.isTrusted,
            isScanning: scanner.isScanning,
            sleepGuard: sleepGuard,
            keepsDisplayAwake: settings.sleepGuardKeepsDisplayAwake,
            showsPower: settings.showPowerFooter,
            powerStatus: statusStore.power,
            showsCountBadge: settings.showCountBadge,
            itemCount: displayItems.count
        )
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

}
