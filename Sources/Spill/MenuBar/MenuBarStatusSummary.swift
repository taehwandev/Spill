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

struct MenuBarStatusSummary: Equatable {
    let title: String
    let tooltip: String
    let segments: [MenuBarStatusSegment]

    static func make(
        enabledItems: Set<SpillMenuBarStatusItem>,
        cpu: SystemCPUStatus,
        memory: SystemMemoryStatus,
        gpu: SystemGPUStatus,
        network: SystemNetworkStatus,
        aiStatuses: [LocalAIToolStatus]
    ) -> MenuBarStatusSummary {
        let orderedItems = SpillMenuBarStatusItem.defaultOrder.filter {
            enabledItems.contains($0) && SpillMenuBarStatusItem.glanceSupported.contains($0)
        }
        guard !orderedItems.isEmpty else {
            return MenuBarStatusSummary(title: "", tooltip: "Show Spill Bar", segments: [])
        }

        let titleParts = orderedItems.map {
            titlePart(for: $0, cpu: cpu, memory: memory, gpu: gpu, network: network, aiStatuses: aiStatuses)
        }
        let tooltipParts = orderedItems.map {
            tooltipPart(for: $0, cpu: cpu, memory: memory, gpu: gpu, network: network, aiStatuses: aiStatuses)
        }
        let segments = orderedItems.compactMap {
            segment(for: $0, cpu: cpu, memory: memory)
        }

        return MenuBarStatusSummary(
            title: titleParts.joined(separator: "  "),
            tooltip: tooltipParts.joined(separator: " | "),
            segments: segments
        )
    }

    private static func segment(
        for item: SpillMenuBarStatusItem,
        cpu: SystemCPUStatus,
        memory: SystemMemoryStatus
    ) -> MenuBarStatusSegment? {
        switch item {
        case .cpu:
            return MenuBarStatusSegment(
                kind: .cpu,
                title: item.title,
                value: compactCPUValue(cpu),
                usageRatio: normalizedRatio(cpu.usageRatio, state: cpu.state),
                state: cpu.state,
                symbolName: item.symbolName
            )
        case .memory:
            return MenuBarStatusSegment(
                kind: .memory,
                title: item.title,
                value: compactMemoryValue(memory),
                usageRatio: normalizedRatio(memory.usageRatio, state: memory.state),
                state: memory.state,
                symbolName: item.symbolName
            )
        case .gpu, .network, .ai:
            return nil
        }
    }

    private static func titlePart(
        for item: SpillMenuBarStatusItem,
        cpu: SystemCPUStatus,
        memory: SystemMemoryStatus,
        gpu: SystemGPUStatus,
        network: SystemNetworkStatus,
        aiStatuses: [LocalAIToolStatus]
    ) -> String {
        switch item {
        case .cpu:
            return "\(item.shortTitle) \(compactCPUValue(cpu))"
        case .memory:
            return "\(item.shortTitle) \(compactMemoryValue(memory))"
        case .gpu:
            return "\(item.shortTitle) \(compactGPUValue(gpu))"
        case .network:
            return "\(item.shortTitle) \(network.value == "N/A" ? "--" : network.value)"
        case .ai:
            return "\(item.shortTitle) \(availableAICount(aiStatuses))/\(aiStatuses.count)"
        }
    }

    private static func tooltipPart(
        for item: SpillMenuBarStatusItem,
        cpu: SystemCPUStatus,
        memory: SystemMemoryStatus,
        gpu: SystemGPUStatus,
        network: SystemNetworkStatus,
        aiStatuses: [LocalAIToolStatus]
    ) -> String {
        switch item {
        case .cpu:
            return details(title: item.title, value: cpu.value, subtitle: cpu.subtitle)
        case .memory:
            return details(title: item.title, value: memory.value, subtitle: memory.subtitle)
        case .gpu:
            return details(title: item.title, value: gpu.value, subtitle: gpu.subtitle)
        case .network:
            return details(title: item.title, value: network.value, subtitle: network.subtitle)
        case .ai:
            let available = availableAICount(aiStatuses)
            let statuses = aiStatuses
                .map { "\($0.title) \($0.value)" }
                .joined(separator: ", ")
            let subtitle = statuses.isEmpty ? nil : statuses
            return details(title: item.title, value: "\(available)/\(aiStatuses.count)", subtitle: subtitle)
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

    private static func compactGPUValue(_ status: SystemGPUStatus) -> String {
        guard status.state != .unavailable else {
            return "--"
        }

        guard status.totalRecommendedMaxWorkingSetBytes > 0 else {
            return compactValue(status.value)
        }

        return "\(compactValue(status.value)) \(SystemMemoryProvider.formatBytes(status.totalRecommendedMaxWorkingSetBytes))"
    }

    private static func normalizedRatio(_ ratio: Double, state: SpillStatusState) -> Double {
        guard state != .unavailable, ratio.isFinite else {
            return 0
        }

        return min(max(ratio, 0), 1)
    }

    private static func availableAICount(_ statuses: [LocalAIToolStatus]) -> Int {
        statuses.filter { status in
            switch status.state {
            case .normal, .active:
                return true
            case .warning, .unavailable, .refreshing:
                return false
            }
        }.count
    }

    private static func details(title: String, value: String, subtitle: String?) -> String {
        guard let subtitle, !subtitle.isEmpty else {
            return "\(title) \(value)"
        }

        return "\(title) \(value) - \(subtitle)"
    }

}
