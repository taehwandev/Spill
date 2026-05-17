import Foundation

struct MenuBarPerformanceEffect: Equatable, Sendable {
    let usageRatio: Double
    let state: SpillStatusState

    static let calm = MenuBarPerformanceEffect(usageRatio: 0, state: .normal)

    var tooltipText: String {
        let percent = Int((usageRatio * 100).rounded())
        switch state {
        case .normal:
            return "calm \(percent)%"
        case .active:
            return "active \(percent)%"
        case .warning:
            return "busy \(percent)%"
        case .refreshing:
            return "sampling"
        case .unavailable:
            return "unavailable"
        }
    }

    static func make(
        cpu: SystemCPUStatus,
        memory: SystemMemoryStatus,
        network: SystemNetworkStatus,
        power: SystemPowerStatus
    ) -> MenuBarPerformanceEffect {
        var ratios: [Double] = []
        var hasWarning = false

        append(cpu.usageRatio, state: cpu.state, to: &ratios, hasWarning: &hasWarning)
        append(memory.usageRatio, state: memory.state, to: &ratios, hasWarning: &hasWarning)
        append(network.activityRatio, state: network.state, to: &ratios, hasWarning: &hasWarning)

        if power.state == .warning {
            ratios.append(0.9)
            hasWarning = true
        } else if power.state == .active {
            ratios.append(0.45)
        }

        guard !ratios.isEmpty else {
            return calm
        }

        let peak = ratios.max() ?? 0
        let average = ratios.reduce(0, +) / Double(ratios.count)
        let usageRatio = (peak * 0.65 + average * 0.35).clamped(to: 0...1)

        if hasWarning || usageRatio >= 0.85 {
            return MenuBarPerformanceEffect(usageRatio: usageRatio, state: .warning)
        }

        if usageRatio >= 0.55 {
            return MenuBarPerformanceEffect(usageRatio: usageRatio, state: .active)
        }

        return MenuBarPerformanceEffect(usageRatio: usageRatio, state: .normal)
    }

    private static func append(
        _ ratio: Double,
        state: SpillStatusState,
        to ratios: inout [Double],
        hasWarning: inout Bool
    ) {
        guard state != .unavailable, state != .refreshing, ratio.isFinite else {
            return
        }

        if state == .warning {
            hasWarning = true
        }

        ratios.append(ratio.clamped(to: 0...1))
    }
}
