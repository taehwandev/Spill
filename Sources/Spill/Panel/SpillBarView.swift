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
    @State private var hoveredStatusModule: SpillStatusModule? = nil

    private var panelState: PanelState {
        panelStore.state
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                header

                if !panelState.visibleStatusModules.isEmpty {
                    Divider()
                        .background(Color.primary.opacity(0.04))
                    statusSection
                }

                if !aiStatusStore.statuses.isEmpty {
                    Divider()
                        .background(Color.primary.opacity(0.04))
                    aiSection
                }

                Divider()
                    .background(Color.primary.opacity(0.04))
                actionSections

                Divider()
                    .background(Color.primary.opacity(0.04))
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
                    .fill(
                        LinearGradient(
                            colors: [.teal, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .indigo.opacity(0.25), radius: 3, y: 1)

                Image(systemName: panelState.readiness.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Spill")
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
        .accessibilityLabel("Spill")
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
                            .foregroundStyle(metricValueTint(for: module, state: status.state))
                    }

                    Text(subtitleText(status.subtitle))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(metricSubtitleTint(for: module))
                }

                Spacer(minLength: 8)

                metricChart(for: module, status: status)
                    .frame(width: 96, height: 28)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 56)
            .background(
                hoveredStatusModule == module ? Color.primary.opacity(0.07) : Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(hoveredStatusModule == module ? 0.08 : 0.05), lineWidth: 0.5)
            }
            .animation(.easeOut(duration: 0.12), value: hoveredStatusModule)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredStatusModule = isHovered ? module : nil
        }
        .popover(isPresented: detailBinding(for: .system(module)), arrowEdge: .top) {
            statusDetailPopover(for: .system(module))
        }
        .help(helpText)
        .accessibilityLabel(helpText)
    }

    private func sectionHeader(_ title: String, symbolName: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary.opacity(0.7))

            Spacer()

            Image(systemName: symbolName)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.7))
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
            return rows.filter { ["Receive", "Upload"].contains($0.label) }
        }
    }

    private func sparklineSeries(for module: SpillStatusModule, tint: Color) -> [MetricSparklineSeries] {
        guard module == .network else {
            return [MetricSparklineSeries(values: statusStore.history(for: module), tint: tint)]
        }

        return [
            MetricSparklineSeries(values: statusStore.networkTrafficHistory.received, tint: .blue),
            MetricSparklineSeries(values: statusStore.networkTrafficHistory.sent, tint: .orange)
        ]
    }

    @ViewBuilder
    private func metricChart(for module: SpillStatusModule, status: SpillStatusMeterSnapshot) -> some View {
        let currentCoreValues = statusStore.cpuCoreHistory.map { $0.last ?? 0 }

        if module == .cpu,
           settings.showsCPUCoreChart,
           !currentCoreValues.isEmpty
        {
            CPUCoreBarChartView(coreValues: currentCoreValues, tint: status.state.panelTint)
        } else {
            MetricSparklineView(
                series: sparklineSeries(for: module, tint: status.state.panelTint),
                normalizesToSeriesMaximum: module == .network
            )
        }
    }

    private func metricValueTint(for module: SpillStatusModule, state: SpillStatusState) -> Color {
        module == .network ? .blue : state.panelTint
    }

    private func metricSubtitleTint(for module: SpillStatusModule) -> Color {
        module == .network ? .orange : .secondary
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
        HStack(alignment: .top, spacing: 20) {
            // Left Column: Directional / Sizing Positions
            VStack(alignment: .center, spacing: 6) {
                Text("POSITIONS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.leading, 1)

                VStack(spacing: 6) {
                    let positions: [[WindowActionKind]] = [
                        [.topLeft, .topHalf, .topRight],
                        [.leftHalf, .center, .rightHalf],
                        [.bottomLeft, .bottomHalf, .bottomRight]
                    ]

                    ForEach(0..<positions.count, id: \.self) { rowIndex in
                        HStack(spacing: 6) {
                            ForEach(positions[rowIndex], id: \.self) { kind in
                                if let action = action(for: kind) {
                                    WindowActionButton(action: action, shortcutKey: shortcutKey(for: action)) {
                                        performWindowAction(action)
                                    }
                                    .help(windowHelpText(for: action))
                                    .accessibilityLabel(action.title)
                                }
                            }
                        }
                    }
                }
            }

            // Right Column: State & Utilities
            VStack(alignment: .center, spacing: 6) {
                Text("UTILITIES")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.leading, 1)

                VStack(spacing: 6) {
                    let utilities: [[WindowActionKind]] = [
                        [.maximize, .restore],
                        [.previousDisplay, .nextDisplay]
                    ]

                    ForEach(0..<utilities.count, id: \.self) { rowIndex in
                        HStack(spacing: 6) {
                            ForEach(utilities[rowIndex], id: \.self) { kind in
                                if let action = action(for: kind) {
                                    WindowActionButton(action: action, shortcutKey: shortcutKey(for: action)) {
                                        performWindowAction(action)
                                    }
                                    .help(windowHelpText(for: action))
                                    .accessibilityLabel(action.title)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 1)
    }

    private func action(for kind: WindowActionKind) -> SpillAction? {
        windowActionStore.actions.first { action in
            if case let .window(actionKind) = action.kind {
                return actionKind == kind
            }
            return false
        }
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

private struct MetricSparklineSeries {
    let values: [Double]
    let tint: Color
}

private struct CPUCoreBarChartView: View {
    let coreValues: [Double]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let values = coreValues.map { $0.clamped(to: 0...1) }
            let coreCount = values.count

            guard coreCount > 0 else {
                drawFlatLine(in: &context, size: size)
                return
            }

            let topInset: CGFloat = 2
            let bottomInset: CGFloat = 2
            let availableHeight = max(size.height - topInset - bottomInset, 1)
            let slotWidth = size.width / CGFloat(coreCount)
            let gap = min(max(slotWidth * 0.24, 0.6), 1.8)
            let barWidth = max(slotWidth - gap, 1)
            let baselineY = size.height - bottomInset

            for (index, value) in values.enumerated() {
                let barHeight = max(availableHeight * CGFloat(value), value > 0 ? 1.2 : 0.8)
                let x = CGFloat(index) * slotWidth + (slotWidth - barWidth) * 0.5
                let rect = CGRect(
                    x: x,
                    y: baselineY - barHeight,
                    width: barWidth,
                    height: barHeight
                )
                let opacity = 0.28 + 0.68 * value
                context.fill(
                    Path(roundedRect: rect, cornerRadius: min(barWidth * 0.45, 1.8)),
                    with: .color(tint.opacity(opacity))
                )
            }
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

private struct MetricSparklineView: View {
    let series: [MetricSparklineSeries]
    var normalizesToSeriesMaximum = false

    var body: some View {
        Canvas { context, size in
            let rawSeries = series.map { series in
                MetricSparklineSeries(
                    values: series.values.suffix(24).map { max($0, 0) },
                    tint: series.tint
                )
            }
            let scale = normalizesToSeriesMaximum
                ? rawSeries.flatMap(\.values).max() ?? 0
                : 1
            let normalizedSeries = rawSeries.map { series in
                MetricSparklineSeries(
                    values: series.values.map { value in
                        if normalizesToSeriesMaximum {
                            guard scale > 0 else {
                                return 0
                            }
                            return min(value / scale, 1)
                        }
                        return min(value, 1)
                    },
                    tint: series.tint
                )
            }

            guard normalizedSeries.contains(where: { $0.values.count >= 2 }),
                  (!normalizesToSeriesMaximum || scale > 0)
            else {
                drawFlatLine(in: &context, size: size)
                return
            }

            for (seriesIndex, series) in normalizedSeries.enumerated() where series.values.count >= 2 {
                let path = smoothedPath(for: series.values, size: size)

                // 1. Draw elegant vertical linear gradient area fill under the curve
                var fillPath = path
                fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                fillPath.addLine(to: CGPoint(x: 0, y: size.height))
                fillPath.closeSubpath()

                let fillOpacity: Double = normalizedSeries.count > 1 ? 0.12 : 0.22
                let gradient = Gradient(colors: [series.tint.opacity(fillOpacity), series.tint.opacity(0.0)])
                context.fill(
                    fillPath,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                // 2. Draw high-end glowing stroked line
                var shadowContext = context
                shadowContext.addFilter(.shadow(color: series.tint.opacity(0.3), radius: 1.5, x: 0, y: 1))
                shadowContext.stroke(
                    path,
                    with: .color(series.tint.opacity(seriesIndex == 0 ? 0.95 : 0.8)),
                    lineWidth: seriesIndex == 0 ? 2.0 : 1.6
                )
            }
        }
        .padding(.vertical, 2)
    }

    private func smoothedPath(for values: [Double], size: CGSize) -> Path {
        var path = Path()
        guard values.count >= 2 else { return path }

        let xStep = size.width / CGFloat(values.count - 1)
        var points: [CGPoint] = []

        for (index, value) in values.enumerated() {
            points.append(CGPoint(
                x: CGFloat(index) * xStep,
                y: size.height - CGFloat(value) * size.height
            ))
        }

        path.move(to: points[0])

        for i in 0..<points.count - 1 {
            let p0 = points[i]
            let p1 = points[i+1]
            let midPoint = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)

            if i == 0 {
                path.addLine(to: midPoint)
            } else {
                path.addQuadCurve(to: midPoint, control: p0)
            }

            if i == points.count - 2 {
                path.addLine(to: p1)
            }
        }

        return path
    }

    private func drawFlatLine(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let y = size.height * 0.5
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        let tint = series.first?.tint ?? .secondary
        context.stroke(path, with: .color(tint.opacity(0.42)), lineWidth: 1.3)
    }
}
