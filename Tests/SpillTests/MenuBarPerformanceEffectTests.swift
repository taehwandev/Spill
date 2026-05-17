import XCTest
@testable import Spill

final class MenuBarPerformanceEffectTests: XCTestCase {
    func testCalmWhenMetricsAreUnavailable() {
        let effect = MenuBarPerformanceEffect.make(
            cpu: cpuStatus(ratio: 0, state: .unavailable),
            memory: memoryStatus(ratio: 0, state: .unavailable),
            network: networkStatus(ratio: 0, state: .unavailable),
            power: powerStatus(ratio: 0, state: .unavailable)
        )

        XCTAssertEqual(effect, .calm)
    }

    func testActiveWhenWeightedLoadIsElevated() {
        let effect = MenuBarPerformanceEffect.make(
            cpu: cpuStatus(ratio: 0.7, state: .active),
            memory: memoryStatus(ratio: 0.6, state: .normal),
            network: networkStatus(ratio: 0.2, state: .normal),
            power: powerStatus(ratio: 1, state: .normal)
        )

        XCTAssertEqual(effect.state, .active)
        XCTAssertGreaterThan(effect.usageRatio, 0.55)
    }

    func testWarningWhenAnyMetricWarns() {
        let effect = MenuBarPerformanceEffect.make(
            cpu: cpuStatus(ratio: 0.2, state: .normal),
            memory: memoryStatus(ratio: 0.91, state: .warning),
            network: networkStatus(ratio: 0.1, state: .normal),
            power: powerStatus(ratio: 1, state: .normal)
        )

        XCTAssertEqual(effect.state, .warning)
    }

    func testNetworkActivityContributesToTriggerLoad() {
        let effect = MenuBarPerformanceEffect.make(
            cpu: cpuStatus(ratio: 0.1, state: .normal),
            memory: memoryStatus(ratio: 0.1, state: .normal),
            network: networkStatus(ratio: 0.9, state: .active),
            power: powerStatus(ratio: 1, state: .normal)
        )

        XCTAssertEqual(effect.state, .active)
        XCTAssertGreaterThan(effect.usageRatio, 0.6)
    }

    private func cpuStatus(ratio: Double, state: SpillStatusState) -> SystemCPUStatus {
        SystemCPUStatus(
            value: "",
            subtitle: nil,
            usageRatio: ratio,
            availableRatio: 1 - ratio,
            userRatio: ratio,
            systemRatio: 0,
            idleRatio: 1 - ratio,
            niceRatio: 0,
            activeTicks: 0,
            totalTicks: 0,
            coreUsageRatios: [],
            peakCoreUsageRatio: ratio,
            coreCount: 0,
            state: state
        )
    }

    private func memoryStatus(ratio: Double, state: SpillStatusState) -> SystemMemoryStatus {
        SystemMemoryStatus(
            value: "",
            subtitle: nil,
            usageRatio: ratio,
            usedBytes: 0,
            availableBytes: 0,
            freeBytes: 0,
            activeBytes: 0,
            inactiveBytes: 0,
            wiredBytes: 0,
            compressedBytes: 0,
            totalBytes: 0,
            state: state
        )
    }

    private func networkStatus(ratio: Double, state: SpillStatusState) -> SystemNetworkStatus {
        SystemNetworkStatus(
            value: "",
            subtitle: nil,
            activityRatio: ratio,
            receivedActivityRatio: ratio,
            sentActivityRatio: ratio,
            receivedBytesPerSecond: 0,
            sentBytesPerSecond: 0,
            totalBytesPerSecond: 0,
            totalReceivedBytes: 0,
            totalSentBytes: 0,
            activeInterfaceCount: 0,
            sampleInterval: 0,
            state: state,
            symbolName: "network"
        )
    }

    private func powerStatus(ratio: Double, state: SpillStatusState) -> SystemPowerStatus {
        SystemPowerStatus(
            value: "",
            subtitle: nil,
            chargeRatio: ratio,
            state: state,
            symbolName: "battery.100",
            hasBattery: true,
            isCharging: false,
            isACPowered: true
        )
    }
}
