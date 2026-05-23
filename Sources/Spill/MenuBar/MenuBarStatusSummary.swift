import Foundation

struct MenuBarStatusSegment: Equatable {
    enum Kind: Equatable {
        case trigger
        case cpu
        case memory
        case caffeine
        case sleepGuard
    }

    enum VisualStyle: Equatable {
        case symbol
        case valueOnly
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
        animates: Bool = false
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
    }
}

extension MenuBarStatusSegment {
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
            animates: animates
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
            animates: false
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
        displayStyle: MenuBarStatusDisplayStyle = .labelAndPercent,
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
                displayStyle: displayStyle,
                precision: precision,
                highlightThreshold: highlightThreshold
            )
        }
        guard !entries.isEmpty else {
            return MenuBarStatusSummary(title: "", tooltip: "Show Spill Bar", segments: [])
        }

        return MenuBarStatusSummary(
            title: entries.map(\.title).joined(separator: "  "),
            tooltip: entries.map(\.tooltip).joined(separator: " | "),
            segments: entries.map(\.segment)
        )
    }

    private static func entry(
        for item: SpillMenuBarStatusItem,
        cpu: SystemCPUStatus,
        memory: SystemMemoryStatus,
        displayStyle: MenuBarStatusDisplayStyle,
        precision: MenuBarStatusPrecision,
        highlightThreshold: MenuBarStatusHighlightThreshold
    ) -> MenuBarStatusEntry? {
        switch item {
        case .cpu:
            let value = compactCPUValue(cpu, precision: precision)
            let displayText = displayStyle.text(label: item.shortTitle, value: value)
            let usageRatio = normalizedRatio(cpu.usageRatio, state: cpu.state)
            let segment = MenuBarStatusSegment(
                kind: .cpu,
                title: item.title,
                shortTitle: item.shortTitle,
                value: value,
                displayText: displayText,
                usageRatio: usageRatio,
                state: displayState(baseState: cpu.state, ratio: usageRatio, highlightThreshold: highlightThreshold),
                symbolName: item.symbolName
            )
            return MenuBarStatusEntry(
                title: displayText,
                tooltip: details(title: item.title, value: cpu.value, subtitle: cpu.subtitle),
                segment: segment
            )
        case .memory:
            let value = compactMemoryValue(memory, precision: precision)
            let displayText = displayStyle.text(label: item.shortTitle, value: value)
            let usageRatio = normalizedRatio(memory.usageRatio, state: memory.state)
            let segment = MenuBarStatusSegment(
                kind: .memory,
                title: item.title,
                shortTitle: item.shortTitle,
                value: value,
                displayText: displayText,
                usageRatio: usageRatio,
                state: displayState(
                    baseState: memory.state,
                    ratio: usageRatio,
                    highlightThreshold: highlightThreshold
                ),
                symbolName: item.symbolName
            )
            return MenuBarStatusEntry(
                title: displayText,
                tooltip: details(title: item.title, value: memory.value, subtitle: memory.subtitle),
                segment: segment
            )
        case .caffeine, .gpu, .network, .ai:
            return nil
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
