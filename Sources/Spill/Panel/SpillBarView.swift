import SwiftUI

struct SpillBarView: View {
    @ObservedObject var panelStore: PanelStore
    @ObservedObject var settings: SpillSettings
    @ObservedObject var statusStore: SystemStatusStore
    @ObservedObject var aiStatusStore: AIStatusStore
    @ObservedObject var windowActionStore: WindowActionStore
    @ObservedObject var sleepGuard: SleepGuardController
    let dismissAction: () -> Void
    let settingsAction: () -> Void
    @State private var pendingDismissWorkItem: DispatchWorkItem?

    private var panelState: PanelState {
        panelStore.state
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                header
                if !panelState.visibleStatusModules.isEmpty {
                    statusSection
                }
                aiSection
                actionSections
                footer
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: panelState.pendingDismiss) { _, pendingDismiss in
            updatePendingDismiss(pendingDismiss)
        }
        .onDisappear {
            pendingDismissWorkItem?.cancel()
            pendingDismissWorkItem = nil
            panelStore.send(.dismissRequestHandled)
        }
    }

    private func updatePendingDismiss(_ pendingDismiss: Bool) {
        pendingDismissWorkItem?.cancel()
        pendingDismissWorkItem = nil

        guard pendingDismiss else {
            return
        }

        let workItem = DispatchWorkItem {
            guard panelStore.state.pendingDismiss else {
                return
            }

            panelStore.send(.dismissRequestHandled)
            dismissAction()
        }
        pendingDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.blue)
                    .shadow(color: Color.blue.opacity(0.3), radius: 3, y: 1)

                Image(systemName: panelState.readiness.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Spill Flow")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(headerSubtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(panelState.actionFeedback?.tint ?? .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            statusDot
            headerCommand(symbolName: "gearshape.fill", title: "Settings", action: settingsAction)
            headerCommand(symbolName: "xmark", title: "Close", action: dismissAction)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spill Flow")
    }

    private func headerCommand(symbolName: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbolName)
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.03), radius: 1, y: 0.5)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private var statusDot: some View {
        Circle()
            .fill(panelState.readiness.tint)
            .frame(width: 8, height: 8)
            .shadow(color: panelState.readiness.tint.opacity(0.4), radius: 2, y: 1)
            .overlay {
                Circle()
                    .stroke(panelState.readiness.tint.opacity(0.22), lineWidth: 5)
            }
            .accessibilityLabel(panelState.readiness.accessibilityLabel)
    }

    private var headerSubtitle: String {
        if let actionFeedback = panelState.actionFeedback {
            return actionFeedback.message
        }

        return panelState.readiness.subtitle(
            count: panelState.itemCount,
            pinnedCount: panelState.pinnedItemCount
        )
    }

    private var statusSection: some View {
        VStack(spacing: 6) {
            sectionHeader("STATUS", symbolName: "waveform.path.ecg")

            VStack(spacing: 7) {
                ForEach(panelState.visibleStatusModules) { module in
                    statusMetricRow(for: module)
                }
            }
        }
    }

    private func statusMetricRow(for module: SpillStatusModule) -> some View {
        let status = statusStore.meterSnapshot(for: module)
        let helpText = statusHelpText(title: module.title, value: status.value, subtitle: status.subtitle)

        return Button {
            panelStore.send(.setStatusDetailTarget(.system(module)))
        } label: {
            HStack(spacing: 10) {
                statusIconBadge(symbolName: module.symbolName, tint: status.state.panelTint)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(module.title)
                            .font(.system(size: 11.5, weight: .semibold))

                        Text(status.value)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(status.state.panelTint)
                    }

                    Text(subtitleText(status.subtitle))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                MetricSparklineView(
                    values: statusStore.history(for: module),
                    tint: status.state.panelTint
                )
                .frame(width: 96, height: 28)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 56)
            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.primary.opacity(0.05), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: detailBinding(for: .system(module)), arrowEdge: .top) {
            statusDetailPopover(for: .system(module))
        }
        .help(helpText)
        .accessibilityLabel(helpText)
    }

    private func sectionHeader(_ title: String, symbolName: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
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
        tint: Color,
        detailRows: [SpillStatusDetailRow] = []
    ) -> some View {
        Button {
            panelStore.send(.setStatusDetailTarget(target))
        } label: {
            compactStatusPill(
                title: title,
                value: value,
                subtitle: subtitle,
                symbolName: symbolName,
                tint: tint,
                detailRows: detailRows
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
        tint: Color,
        detailRows: [SpillStatusDetailRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                statusIconBadge(symbolName: symbolName, tint: tint)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer(minLength: 2)

                        Text(value)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .monospacedDigit()
                    }

                    Text(subtitleText(subtitle))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .monospacedDigit()
                        .foregroundStyle(tint.opacity(0.72))
                }
            }

            if !detailRows.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(detailRows.prefix(3)) { row in
                        HStack(spacing: 4) {
                            Text(row.label)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            Text(row.value)
                                .monospacedDigit()
                        }
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: detailRows.isEmpty ? 60 : 92)
        .frame(maxWidth: .infinity)
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusIconBadge(symbolName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.14))

            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .bold))
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 30, height: 30)
    }

    private func inlineRows(for module: SpillStatusModule) -> [SpillStatusDetailRow] {
        let rows = statusStore.detailRows(for: module)

        switch module {
        case .cpu:
            return rows.filter { ["User", "System", "Idle"].contains($0.label) }
        case .memory:
            return rows.filter { ["Used", "Wired", "Compressed"].contains($0.label) }
        case .storage:
            return rows.filter { ["Used", "Available", "Total"].contains($0.label) }
        case .gpu:
            return rows.filter { ["Available", "Budget"].contains($0.label) }
        case .network:
            return rows.filter { ["Route", "Reachable"].contains($0.label) }
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
            panelState.statusDetailTarget == target
        } set: { isPresented in
            if isPresented {
                panelStore.send(.setStatusDetailTarget(target))
            } else if panelState.statusDetailTarget == target {
                panelStore.send(.setStatusDetailTarget(nil))
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
        case .storage:
            return nil
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
        panelStore.send(.performWindowAction(action))
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
        "No Notch Candidates"
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
                    .frame(height: 50)
            } else {
                windowActionGrid
            }
        }
    }

    private var menuBarActionsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionHeader("MENU BAR", symbolName: "menubar.rectangle")

            Group {
                if panelState.readiness == .permissionRequired {
                    inlineState(symbolName: "lock.fill", title: "Accessibility Required")
                        .frame(height: 48)
                } else if panelState.readiness == .scanning && panelState.displayItems.isEmpty {
                    scanningState
                        .frame(height: 48)
                } else if panelState.actionItems.isEmpty {
                    inlineState(symbolName: "magnifyingglass", title: emptyStateTitle)
                        .frame(height: 48)
                } else {
                    menuBarActionGrid
                }
            }
        }
    }

    private var windowActionGrid: some View {
        LazyVGrid(columns: windowActionGridColumns, alignment: .leading, spacing: 6) {
            ForEach(windowActionStore.actions) { action in
                WindowActionButton(action: action, shortcutKey: shortcutKey(for: action)) {
                    performWindowAction(action)
                }
                .help(windowHelpText(for: action))
                .accessibilityLabel(action.title)
            }
        }
        .padding(.horizontal, 1)
    }

    private var windowActionGridColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 76, maximum: 76),
                spacing: 6,
                alignment: .center
            )
        ]
    }

    private var menuBarActionGrid: some View {
        LazyVGrid(columns: menuBarActionGridColumns, alignment: .leading, spacing: 6) {
            ForEach(panelState.actionItems) { item in
                SpillActionButton(
                    action: item.action,
                    isPinned: item.isPinned,
                    togglePinned: { panelStore.send(.togglePinned(item.sourceItem)) },
                    perform: { perform(item) }
                )
                .help(helpText(for: item))
                .accessibilityLabel(item.action.title)
            }
        }
        .padding(.horizontal, 1)
    }

    private var menuBarActionGridColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 48, maximum: 48),
                spacing: max(CGFloat(settings.iconSpacing), 7),
                alignment: .center
            )
        ]
    }

    private func shortcutKey(for action: SpillAction) -> WindowActionShortcutKey {
        guard case let .window(kind) = action.kind else {
            return .off
        }

        return settings.shortcutKey(for: kind)
    }

    private func perform(_ item: SpillDisplayedActionItem) {
        panelStore.send(.performMenuBarAction(item))
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
    }

    private var footer: some View {
        SpillFooterView(
            isAccessibilityTrusted: panelState.readiness != .permissionRequired,
            isScanning: panelState.readiness == .scanning,
            sleepGuard: sleepGuard,
            sleepGuardDefaultDuration: settings.sleepGuardDefaultDuration,
            allowsIndefiniteDuration: settings.sleepGuardAllowsIndefinite,
            keepsDisplayAwake: settings.sleepGuardKeepsDisplayAwake,
            showsPower: true,
            powerStatus: statusStore.power,
            showsCountBadge: true,
            itemCount: panelState.itemCount
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

private struct MetricSparklineView: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let normalizedValues = values
                .suffix(24)
                .map { min(max($0, 0), 1) }

            guard normalizedValues.count >= 2 else {
                drawFlatLine(in: &context, size: size)
                return
            }

            var path = Path()
            let xStep = size.width / CGFloat(normalizedValues.count - 1)

            for (index, value) in normalizedValues.enumerated() {
                let point = CGPoint(
                    x: CGFloat(index) * xStep,
                    y: size.height - CGFloat(value) * size.height
                )

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            var shadowContext = context
            shadowContext.addFilter(.shadow(color: tint.opacity(0.3), radius: 1, x: 0, y: 1))
            shadowContext.stroke(path, with: .color(tint.opacity(0.9)), lineWidth: 1.8)
        }
        .padding(.vertical, 2)
    }

    private func drawFlatLine(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let y = size.height * 0.5
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(path, with: .color(tint.opacity(0.42)), lineWidth: 1.3)
    }
}
