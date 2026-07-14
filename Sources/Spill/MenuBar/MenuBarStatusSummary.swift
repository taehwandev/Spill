import Foundation

struct MenuBarStatusSegment: Equatable {
    struct GraphSeries: Equatable, Sendable {
        enum Role: Equatable, Sendable {
            case status
            case received
            case sent
        }

        let role: Role
        let values: [Double]
    }

    enum Kind: Equatable {
        case trigger
        case cpu
        case memory
        case network
        case caffeine
        case ai
        case sleepGuard
    }

    enum VisualStyle: Equatable {
        case symbol
        case valueOnly
        case chart
        case symbolBadge
        case trigger(MenuBarTriggerIconStyle)
    }

    let kind: Kind
    let title: String
    let shortTitle: String
    let value: String
    let displayText: String
    let usageRatio: Double
    let state: SpillStatusState
    let symbolName: String
    let visualStyle: VisualStyle
    let animates: Bool
    let graphSeries: [GraphSeries]

    init(
        kind: Kind,
        title: String,
        shortTitle: String,
        value: String,
        displayText: String,
        usageRatio: Double,
        state: SpillStatusState,
        symbolName: String,
        visualStyle: VisualStyle = .symbol,
        animates: Bool = false,
        graphSeries: [GraphSeries] = []
    ) {
        self.kind = kind
        self.title = title
        self.shortTitle = shortTitle
        self.value = value
        self.displayText = displayText
        self.usageRatio = usageRatio
        self.state = state
        self.symbolName = symbolName
        self.visualStyle = visualStyle
        self.animates = animates
        self.graphSeries = graphSeries
    }
}

extension MenuBarStatusSegment {
    var showsHistoryGraph: Bool {
        usesChartPresentation && !graphSeries.isEmpty
    }

    var usesChartPresentation: Bool {
        if case .chart = visualStyle {
            return true
        }

        return false
    }

    func chartMenuBarSegment() -> MenuBarStatusSegment {
        guard kind == .cpu || kind == .memory || kind == .network else {
            return self
        }

        return MenuBarStatusSegment(
            kind: kind,
            title: title,
            shortTitle: shortTitle,
            value: value,
            displayText: displayText,
            usageRatio: usageRatio,
            state: state,
            symbolName: symbolName,
            visualStyle: .chart,
            animates: false,
            graphSeries: graphSeries
        )
    }

    func withoutMenuBarValue() -> MenuBarStatusSegment {
        MenuBarStatusSegment(
            kind: kind,
            title: title,
            shortTitle: shortTitle,
            value: "",
            displayText: "",
            usageRatio: usageRatio,
            state: state,
            symbolName: symbolName,
            visualStyle: visualStyle,
            animates: animates,
            graphSeries: graphSeries
        )
    }

    func badgeMenuBarSegment() -> MenuBarStatusSegment {
        MenuBarStatusSegment(
            kind: kind,
            title: title,
            shortTitle: shortTitle,
            value: value,
            displayText: displayText,
            usageRatio: usageRatio,
            state: state,
            symbolName: symbolName,
            visualStyle: .symbolBadge,
            animates: false,
            graphSeries: graphSeries
        )
    }

    func valueOnlyMenuBarSegment() -> MenuBarStatusSegment {
        MenuBarStatusSegment(
            kind: kind,
            title: title,
            shortTitle: shortTitle,
            value: value,
            displayText: displayText,
            usageRatio: usageRatio,
            state: state,
            symbolName: symbolName,
            visualStyle: .valueOnly,
            animates: false,
            graphSeries: graphSeries
        )
    }
}

private struct MenuBarStatusEntry {
    let title: String
    let tooltip: String
    let segment: MenuBarStatusSegment
}

struct MenuBarStatusSummary: Equatable {
    let title: String
    let tooltip: String
    let segments: [MenuBarStatusSegment]

    static func make(
        enabledItems: Set<SpillMenuBarStatusItem>,
        cpu: SystemCPUStatus,
        memory: SystemMemoryStatus,
        network: SystemNetworkStatus = SystemNetworkProvider.status(previous: nil, current: nil),
        cpuHistory: [Double] = [],
        memoryHistory: [Double] = [],
        networkHistory: SystemNetworkTrafficHistory = SystemNetworkTrafficHistory(received: [], sent: []),
        aiTokenCount: Int = 0,
        aiAllTimeTokenCount: Int = 0,
        displayMode: MenuBarTokenDisplayMode = .daily,
        aiServerHealth: CloudServiceHealth? = nil,
        precision: MenuBarStatusPrecision = .tenths,
        highlightThreshold: MenuBarStatusHighlightThreshold = .seventy
    ) -> MenuBarStatusSummary {
        let orderedItems = SpillMenuBarStatusItem.defaultOrder.filter {
            enabledItems.contains($0) && SpillMenuBarStatusItem.glanceSupported.contains($0)
        }
        let entries = orderedItems.compactMap {
            entry(
                for: $0,
                cpu: cpu,
                memory: memory,
                network: network,
                cpuHistory: cpuHistory,
                memoryHistory: memoryHistory,
                networkHistory: networkHistory,
                aiTokenCount: aiTokenCount,
                aiAllTimeTokenCount: aiAllTimeTokenCount,
                displayMode: displayMode,
                aiServerHealth: aiServerHealth,
                precision: precision,
                highlightThreshold: highlightThreshold
            )
        }
        guard !entries.isEmpty else {
            return MenuBarStatusSummary(title: "", tooltip: AppL10n.text(.showSpillPanel), segments: [])
        }

        return MenuBarStatusSummary(
            title: entries.map(\.title).joined(separator: "  "),
            tooltip: entries.map(\.tooltip).joined(separator: " | "),
            segments: entries.map(\.segment)
        )
    }
}

private extension MenuBarStatusSummary {
    private static func entry(
        for item: SpillMenuBarStatusItem,
        cpu: SystemCPUStatus,
        memory: SystemMemoryStatus,
        network: SystemNetworkStatus,
        cpuHistory: [Double],
        memoryHistory: [Double],
        networkHistory: SystemNetworkTrafficHistory,
        aiTokenCount: Int,
        aiAllTimeTokenCount: Int,
        displayMode: MenuBarTokenDisplayMode,
        aiServerHealth: CloudServiceHealth?,
        precision: MenuBarStatusPrecision,
        highlightThreshold: MenuBarStatusHighlightThreshold
    ) -> MenuBarStatusEntry? {
        switch item {
        case .cpu:
            return metricEntry(
                item: item,
                kind: .cpu,
                value: compactCPUValue(cpu, precision: precision),
                detailValue: cpu.value,
                subtitle: cpu.subtitle,
                usageRatio: cpu.usageRatio,
                state: cpu.state,
                graphSeries: [MenuBarStatusSegment.GraphSeries(role: .status, values: cpu.coreUsageRatios.isEmpty ? [cpu.usageRatio] : cpu.coreUsageRatios)],
                highlightThreshold: highlightThreshold
            )
        case .memory:
            return metricEntry(
                item: item,
                kind: .memory,
                value: compactMemoryValue(memory, precision: precision),
                detailValue: memory.value,
                subtitle: memory.subtitle,
                usageRatio: memory.usageRatio,
                state: memory.state,
                graphSeries: [MenuBarStatusSegment.GraphSeries(role: .status, values: memoryHistory)],
                highlightThreshold: highlightThreshold
            )
        case .network:
            return metricEntry(
                item: item,
                kind: .network,
                value: networkValue(received: network.value, sent: network.subtitle),
                detailValue: network.value,
                subtitle: network.subtitle,
                usageRatio: network.activityRatio,
                state: network.state,
                graphSeries: [
                    MenuBarStatusSegment.GraphSeries(role: .received, values: networkHistory.received),
                    MenuBarStatusSegment.GraphSeries(role: .sent, values: networkHistory.sent)
                ],
                highlightThreshold: highlightThreshold
            )
        case .ai:
            let value: String
            switch displayMode {
            case .daily:
                value = TokenUsageDashboardSnapshot.formatTokens(aiTokenCount)
            case .total:
                value = TokenUsageDashboardSnapshot.formatTokens(aiAllTimeTokenCount)
            case .dailyAndTotal:
                let dailyStr = TokenUsageDashboardSnapshot.formatTokens(aiTokenCount)
                let totalStr = TokenUsageDashboardSnapshot.formatTokens(aiAllTimeTokenCount)
                value = "\(dailyStr)/\(totalStr)"
            case .cycle:
                let showDaily = Int(Date().timeIntervalSince1970) / 4 % 2 == 0
                let count = showDaily ? aiTokenCount : aiAllTimeTokenCount
                value = TokenUsageDashboardSnapshot.formatTokens(count)
            }
            let displayText = displayText(label: item.shortTitle, value: value)
            let state = aiStatusState(for: aiServerHealth)
            let segment = MenuBarStatusSegment(
                kind: .ai,
                title: item.title,
                shortTitle: item.shortTitle,
                value: value,
                displayText: displayText,
                usageRatio: 0,
                state: state,
                symbolName: item.symbolName
            )
            var tooltipParts = [
                AppL10n.tokenMeteringAccessibility(tokenCount: value),
                AppL10n.text(.openLocalTokenDashboard)
            ]
            if let aiServerHealth {
                tooltipParts.append("\(AppL10n.text(.server)) \(aiServerHealth.serverStatusHeaderTitle)")
            }
            return MenuBarStatusEntry(
                title: displayText,
                tooltip: tooltipParts.joined(separator: " - "),
                segment: segment
            )
        case .caffeine, .gpu:
            return nil
        }
    }
}

private extension MenuBarStatusSummary {
    private static func metricEntry(
        item: SpillMenuBarStatusItem,
        kind: MenuBarStatusSegment.Kind,
        value: String,
        detailValue: String,
        subtitle: String?,
        usageRatio: Double,
        state: SpillStatusState,
        graphSeries: [MenuBarStatusSegment.GraphSeries],
        highlightThreshold: MenuBarStatusHighlightThreshold
    ) -> MenuBarStatusEntry {
        let displayText = displayText(label: item.shortTitle, value: value)
        let normalizedUsageRatio = normalizedRatio(usageRatio, state: state)
        let segment = MenuBarStatusSegment(
            kind: kind,
            title: item.title,
            shortTitle: item.shortTitle,
            value: value,
            displayText: displayText,
            usageRatio: normalizedUsageRatio,
            state: displayState(
                baseState: state,
                ratio: normalizedUsageRatio,
                highlightThreshold: highlightThreshold
            ),
            symbolName: item.symbolName,
            graphSeries: graphSeries
        )
        return MenuBarStatusEntry(
            title: displayText,
            tooltip: details(title: item.title, value: detailValue, subtitle: subtitle),
            segment: segment
        )
    }

    private static func displayText(label: String, value: String) -> String {
        "\(label) \(value)"
    }

    private static func networkValue(received: String, sent: String?) -> String {
        [received, sent].compactMap { $0 }.joined(separator: " ")
    }

    private static func aiStatusState(for health: CloudServiceHealth?) -> SpillStatusState {
        switch health {
        case .degraded, .outage, .maintenance:
            return .warning
        case .unknown:
            return .unavailable
        case .operational, .none:
            return .normal
        }
    }

    private static func compactCPUValue(
        _ status: SystemCPUStatus,
        precision: MenuBarStatusPrecision
    ) -> String {
        guard status.state != .unavailable, status.state != .refreshing else {
            return "--"
        }

        return precision.percentText(for: status.usageRatio)
    }

    private static func compactMemoryValue(
        _ status: SystemMemoryStatus,
        precision: MenuBarStatusPrecision
    ) -> String {
        guard status.state != .unavailable else {
            return "--"
        }

        return precision.percentText(for: status.usageRatio)
    }

    private static func normalizedRatio(_ ratio: Double, state: SpillStatusState) -> Double {
        guard state != .unavailable, ratio.isFinite else {
            return 0
        }

        return min(max(ratio, 0), 1)
    }

    private static func displayState(
        baseState: SpillStatusState,
        ratio: Double,
        highlightThreshold: MenuBarStatusHighlightThreshold
    ) -> SpillStatusState {
        guard baseState != .unavailable else {
            return .unavailable
        }

        guard baseState != .refreshing else {
            return .refreshing
        }

        if ratio >= MenuBarStatusHighlightThreshold.ninety.ratio {
            return .warning
        }

        if ratio >= highlightThreshold.ratio {
            return .active
        }

        return .normal
    }

    private static func details(title: String, value: String, subtitle: String?) -> String {
        guard let subtitle, !subtitle.isEmpty else {
            return "\(title) \(value)"
        }

        return "\(title) \(value) - \(subtitle)"
    }
}
