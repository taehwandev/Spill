import XCTest
@testable import Spill

final class MenuBarStatusSummaryTests: XCTestCase {
    func testSummaryFormatsEnabledItemsInDefaultOrder() {
        let summary = MenuBarStatusSummary.make(
            enabledItems: [.ai, .gpu, .memory, .cpu],
            cpu: SystemCPUProvider.status(
                previous: SystemCPUReading(userTicks: 0, systemTicks: 0, idleTicks: 80, niceTicks: 0),
                current: SystemCPUReading(userTicks: 12, systemTicks: 8, idleTicks: 160, niceTicks: 0)
            ),
            memory: SystemMemoryProvider.status(
                from: SystemMemoryReading(
                    totalBytes: gib(16),
                    freeBytes: gib(2),
                    activeBytes: gib(6),
                    inactiveBytes: gib(1),
                    wiredBytes: gib(2),
                    compressedBytes: gib(1)
                )
            ),
            aiTokenCount: 1_439_865
        )

        XCTAssertEqual(summary.title, "CPU 20.0%  MEM 56.2%  AI 1.44M")
        XCTAssertEqual(summary.segments.count, 3)
        XCTAssertEqual(summary.segments.map(\.kind), [.cpu, .memory, .ai])
        XCTAssertEqual(summary.segments.map(\.value), ["20.0%", "56.2%", "1.44M"])
        XCTAssertEqual(summary.segments.map(\.displayText), ["CPU 20.0%", "MEM 56.2%", "AI 1.44M"])
        XCTAssertEqual(summary.segments.map(\.symbolName), ["cpu", "memorychip", "sparkles"])
        XCTAssertEqual(summary.segments[0].usageRatio, 0.2, accuracy: 0.0001)
        XCTAssertEqual(summary.segments[1].usageRatio, 0.5625, accuracy: 0.0001)
        XCTAssertTrue(summary.tooltip.contains("CPU 20.0%"))
        XCTAssertTrue(summary.tooltip.contains("Memory 56.2%"))
        XCTAssertFalse(summary.tooltip.contains("GPU 1/1"))
        XCTAssertTrue(summary.tooltip.contains("Token Metering, 1.44M local tokens"))
        XCTAssertTrue(summary.tooltip.contains("Open Local Token Dashboard"))
        XCTAssertFalse(summary.tooltip.contains("secret"))
    }

    func testEmptySummaryKeepsIconOnlyFallback() {
        let summary = MenuBarStatusSummary.make(
            enabledItems: [],
            cpu: SystemCPUProvider.status(previous: nil, current: nil),
            memory: SystemMemoryProvider.status(from: nil)
        )

        XCTAssertEqual(summary.title, "")
        XCTAssertEqual(summary.tooltip, "Show Spill Panel")
        XCTAssertEqual(summary.segments, [])
    }

    func testSummarySupportsTenthsFormatting() {
        let summary = MenuBarStatusSummary.make(
            enabledItems: [.memory, .cpu],
            cpu: SystemCPUProvider.status(
                previous: SystemCPUReading(userTicks: 0, systemTicks: 0, idleTicks: 80, niceTicks: 0),
                current: SystemCPUReading(userTicks: 12, systemTicks: 8, idleTicks: 160, niceTicks: 0)
            ),
            memory: SystemMemoryProvider.status(
                from: SystemMemoryReading(
                    totalBytes: gib(16),
                    freeBytes: gib(2),
                    activeBytes: gib(6),
                    inactiveBytes: gib(1),
                    wiredBytes: gib(2),
                    compressedBytes: gib(1)
                )
            ),
            precision: .tenths
        )

        XCTAssertEqual(summary.title, "CPU 20.0%  MEM 56.2%")
        XCTAssertEqual(summary.segments.map(\.displayText), ["CPU 20.0%", "MEM 56.2%"])
        XCTAssertEqual(summary.segments.map(\.value), ["20.0%", "56.2%"])
    }

    func testSummaryUsesPlaceholderWhileCPUIsSampling() {
        let summary = MenuBarStatusSummary.make(
            enabledItems: [.cpu],
            cpu: SystemCPUProvider.status(previous: nil, current: nil),
            memory: SystemMemoryProvider.status(from: nil)
        )

        XCTAssertEqual(summary.title, "CPU --")
        XCTAssertEqual(summary.segments.map(\.value), ["--"])
        XCTAssertEqual(summary.segments.map(\.state), [.refreshing])
        XCTAssertTrue(summary.tooltip.contains("CPU Sampling"))
    }

    func testPercentPrecisionUsesLessThanForTinyNonZeroUsage() {
        XCTAssertEqual(MenuBarStatusPrecision.whole.percentText(for: 0), "0%")
        XCTAssertEqual(MenuBarStatusPrecision.whole.percentText(for: 0.0005), "<1%")
        XCTAssertEqual(MenuBarStatusPrecision.tenths.percentText(for: 0.0005), "<0.1%")
        XCTAssertEqual(MenuBarStatusPrecision.tenths.percentText(for: 0.001), "0.1%")
    }

    func testSummaryUsesConfiguredHighlightThresholdForMenuBarState() {
        let summary = MenuBarStatusSummary.make(
            enabledItems: [.cpu],
            cpu: SystemCPUProvider.status(
                previous: SystemCPUReading(userTicks: 0, systemTicks: 0, idleTicks: 80, niceTicks: 0),
                current: SystemCPUReading(userTicks: 75, systemTicks: 5, idleTicks: 100, niceTicks: 0)
            ),
            memory: SystemMemoryProvider.status(from: nil),
            highlightThreshold: .eighty
        )

        XCTAssertEqual(summary.segments.map(\.state), [.active])
    }

    func testSummaryUsesWarningAtExactNinetyPercentWithNinetyThreshold() {
        let summary = MenuBarStatusSummary.make(
            enabledItems: [.cpu, .memory],
            cpu: SystemCPUProvider.status(
                previous: SystemCPUReading(userTicks: 0, systemTicks: 0, idleTicks: 100, niceTicks: 0),
                current: SystemCPUReading(userTicks: 90, systemTicks: 0, idleTicks: 110, niceTicks: 0)
            ),
            memory: SystemMemoryProvider.status(
                from: SystemMemoryReading(
                    totalBytes: gib(10),
                    freeBytes: 0,
                    activeBytes: gib(7),
                    inactiveBytes: gib(1),
                    wiredBytes: gib(1),
                    compressedBytes: gib(1)
                )
            ),
            highlightThreshold: .ninety
        )

        XCTAssertEqual(summary.title, "CPU 90.0%  MEM 90.0%")
        XCTAssertEqual(summary.segments.map(\.state), [.warning, .warning])
        XCTAssertEqual(summary.segments.map(\.usageRatio), [0.9, 0.9])
    }

    private func gib(_ value: UInt64) -> UInt64 {
        value * 1_073_741_824
    }
}
