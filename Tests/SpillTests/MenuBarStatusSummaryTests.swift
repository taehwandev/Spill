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
            )
        )

        XCTAssertEqual(summary.title, "CPU 20%  MEM 56%")
        XCTAssertEqual(summary.segments.count, 2)
        XCTAssertEqual(summary.segments.map(\.kind), [.cpu, .memory])
        XCTAssertEqual(summary.segments.map(\.value), ["20%", "56%"])
        XCTAssertEqual(summary.segments.map(\.displayText), ["CPU 20%", "MEM 56%"])
        XCTAssertEqual(summary.segments.map(\.symbolName), ["cpu", "memorychip"])
        XCTAssertEqual(summary.segments[0].usageRatio, 0.2, accuracy: 0.0001)
        XCTAssertEqual(summary.segments[1].usageRatio, 0.5625, accuracy: 0.0001)
        XCTAssertTrue(summary.tooltip.contains("CPU 20%"))
        XCTAssertTrue(summary.tooltip.contains("Memory 56%"))
        XCTAssertFalse(summary.tooltip.contains("GPU 1/1"))
        XCTAssertFalse(summary.tooltip.contains("AI 2/3"))
        XCTAssertFalse(summary.tooltip.contains("secret"))
    }

    func testEmptySummaryKeepsIconOnlyFallback() {
        let summary = MenuBarStatusSummary.make(
            enabledItems: [],
            cpu: SystemCPUProvider.status(previous: nil, current: nil),
            memory: SystemMemoryProvider.status(from: nil)
        )

        XCTAssertEqual(summary.title, "")
        XCTAssertEqual(summary.tooltip, "Show Spill Bar")
        XCTAssertEqual(summary.segments, [])
    }

    func testSummarySupportsPercentOnlyAndTenthsFormatting() {
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
            displayStyle: .percentOnly,
            precision: .tenths
        )

        XCTAssertEqual(summary.title, "20.0%  56.2%")
        XCTAssertEqual(summary.segments.map(\.displayText), ["20.0%", "56.2%"])
        XCTAssertEqual(summary.segments.map(\.value), ["20.0%", "56.2%"])
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

    private func gib(_ value: UInt64) -> UInt64 {
        value * 1_073_741_824
    }
}
