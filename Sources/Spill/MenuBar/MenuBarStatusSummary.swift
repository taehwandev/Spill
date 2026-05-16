import Foundation

struct MenuBarStatusSegment: Equatable {
    enum Kind: Equatable {
        case cpu
        case memory
    }

    let kind: Kind
    let title: String
    let value: String
    let usageRatio: Double
    let state: SpillStatusState
    let symbolName: String
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
        memory: SystemMemoryStatus
    ) -> MenuBarStatusSummary {
        let orderedItems = SpillMenuBarStatusItem.defaultOrder.filter {
            enabledItems.contains($0) && SpillMenuBarStatusItem.glanceSupported.contains($0)
        }
        let entries = orderedItems.compactMap {
            entry(for: $0, cpu: cpu, memory: memory)
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
        memory: SystemMemoryStatus
    ) -> MenuBarStatusEntry? {
        switch item {
        case .cpu:
            let segment = MenuBarStatusSegment(
                kind: .cpu,
                title: item.title,
                value: compactCPUValue(cpu),
                usageRatio: normalizedRatio(cpu.usageRatio, state: cpu.state),
                state: cpu.state,
                symbolName: item.symbolName
            )
            return MenuBarStatusEntry(
                title: "\(item.shortTitle) \(segment.value)",
                tooltip: details(title: item.title, value: cpu.value, subtitle: cpu.subtitle),
                segment: segment
            )
        case .memory:
            let segment = MenuBarStatusSegment(
                kind: .memory,
                title: item.title,
                value: compactMemoryValue(memory),
                usageRatio: normalizedRatio(memory.usageRatio, state: memory.state),
                state: memory.state,
                symbolName: item.symbolName
            )
            return MenuBarStatusEntry(
                title: "\(item.shortTitle) \(segment.value)",
                tooltip: details(title: item.title, value: memory.value, subtitle: memory.subtitle),
                segment: segment
            )
        case .gpu, .network, .ai:
            return nil
        }
    }

    private static func compactValue(_ value: String) -> String {
        value == "N/A" ? "--" : value
    }

    private static func compactCPUValue(_ status: SystemCPUStatus) -> String {
        guard status.state != .unavailable else {
            return "--"
        }

        return compactValue(status.value)
    }

    private static func compactMemoryValue(_ status: SystemMemoryStatus) -> String {
        guard status.state != .unavailable else {
            return "--"
        }

        return compactValue(status.value)
    }

    private static func normalizedRatio(_ ratio: Double, state: SpillStatusState) -> Double {
        guard state != .unavailable, ratio.isFinite else {
            return 0
        }

        return min(max(ratio, 0), 1)
    }

    private static func details(title: String, value: String, subtitle: String?) -> String {
        guard let subtitle, !subtitle.isEmpty else {
            return "\(title) \(value)"
        }

        return "\(title) \(value) - \(subtitle)"
    }

}
