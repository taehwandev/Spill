import AppKit
import XCTest
@testable import Spill

@MainActor
final class MenuBarStatusContentViewTests: XCTestCase {
    func testStatusControllerPlacesCaffeineAtLeftEdge() {
        let trigger = MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
        let cpu = MenuBarStatusSegment(
            kind: .cpu,
            title: "CPU",
            shortTitle: "CPU",
            value: "20.0%",
            displayText: "CPU 20.0%",
            usageRatio: 0.2,
            state: .normal,
            symbolName: "cpu"
        )
        let memory = MenuBarStatusSegment(
            kind: .memory,
            title: "Memory",
            shortTitle: "MEM",
            value: "60.0%",
            displayText: "MEM 60.0%",
            usageRatio: 0.6,
            state: .normal,
            symbolName: "memorychip"
        )
        let caffeine = MenuBarStatusSegment(
            kind: .caffeine,
            title: "Caffeine",
            shortTitle: "CAF",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .unavailable,
            symbolName: "cup.and.saucer"
        )

        let segments = StatusItemController.orderedSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine
        )

        XCTAssertEqual(segments.map(\.kind), [.caffeine, .trigger, .cpu, .memory])
    }

    func testSegmentHitTestingFindsCaffeineChip() {
        let trigger = MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
        let caffeine = MenuBarStatusSegment(
            kind: .caffeine,
            title: "Caffeine",
            shortTitle: "CAF",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .unavailable,
            symbolName: "cup.and.saucer"
        )
        let cpu = MenuBarStatusSegment(
            kind: .cpu,
            title: "CPU",
            shortTitle: "CPU",
            value: "20.0%",
            displayText: "CPU 20.0%",
            usageRatio: 0.2,
            state: .normal,
            symbolName: "cpu"
        )

        let triggerWidth = MenuBarStatusContentView.preferredWidth(for: [trigger])
        let caffeineOnlyWidth = MenuBarStatusContentView.preferredWidth(for: [caffeine])

        let segments = [caffeine, trigger, cpu]

        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: 4, y: 10), in: segments),
            .caffeine
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: caffeineOnlyWidth + 4, y: 10),
                in: segments
            ),
            .trigger
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: caffeineOnlyWidth + triggerWidth + 4, y: 10),
                in: segments
            ),
            .cpu
        )
        XCTAssertNil(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: 9_999, y: 10), in: segments)
        )
    }

    func testTriggerUsesLargerIconOnlyFootprintThanCaffeine() {
        let trigger = MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
        let caffeine = MenuBarStatusSegment(
            kind: .caffeine,
            title: "Caffeine",
            shortTitle: "CAF",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .unavailable,
            symbolName: "cup.and.saucer"
        )

        XCTAssertGreaterThan(
            MenuBarStatusContentView.preferredWidth(for: [trigger]),
            MenuBarStatusContentView.preferredWidth(for: [caffeine])
        )
    }

    func testStatusChipsDoNotDrawRoundedBackgrounds() {
        let trigger = MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
        let cpu = MenuBarStatusSegment(
            kind: .cpu,
            title: "CPU",
            shortTitle: "CPU",
            value: "20.0%",
            displayText: "CPU 20.0%",
            usageRatio: 0.2,
            state: .normal,
            symbolName: "cpu"
        )

        let view = MenuBarStatusContentView(segments: [trigger, cpu])

        XCTAssertEqual(view.subviews.count, 2)
        view.subviews.forEach { chip in
            XCTAssertFalse(chip.wantsLayer)
            XCTAssertNil(chip.layer?.backgroundColor)
        }
    }

    func testVisibleSegmentsKeepAllRequestedSegmentsWhenTheyFit() {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment(value: "15m", active: true)
        let cpu = makeStatusSegment(kind: .cpu, value: "20.0%")
        let memory = makeStatusSegment(kind: .memory, value: "60.0%")

        let segments = StatusItemController.visibleSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine,
            maximumWidth: 1_000
        )

        XCTAssertEqual(segments.map(\.kind), [.caffeine, .trigger, .cpu, .memory])
        XCTAssertEqual(segments.first?.value, "15m")
    }

    func testVisibleSegmentsUseValueOnlyStatusSegmentsWhenActiveStateWouldOverflow() {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment(value: "1h 59m", active: true)
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%")
        let memory = makeStatusSegment(kind: .memory, value: "90.0%")
        let compactSegments = StatusItemController.orderedSegments(
            trigger: trigger,
            statusSegments: [cpu.valueOnlyMenuBarSegment(), memory.valueOnlyMenuBarSegment()],
            caffeineSegment: caffeine.withoutMenuBarValue()
        )
        let compactWidth = MenuBarStatusContentView.preferredWidth(for: compactSegments)

        let segments = StatusItemController.visibleSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine,
            maximumWidth: compactWidth
        )

        XCTAssertEqual(segments.map(\.kind), [.caffeine, .trigger, .cpu, .memory])
        XCTAssertEqual(segments.first?.value, "")
        XCTAssertEqual(segments.suffix(2).map(\.value), ["90.0%", "90.0%"])
        XCTAssertEqual(segments.suffix(2).map(\.visualStyle), [.valueOnly, .valueOnly])
        XCTAssertLessThanOrEqual(MenuBarStatusContentView.preferredWidth(for: segments), compactWidth)
    }

    func testVisibleSegmentsDropStatusOnlyAfterValueOnlySegmentsStillOverflow() {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment(value: "1h 59m", active: true)
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%")
        let memory = makeStatusSegment(kind: .memory, value: "90.0%")

        let segments = StatusItemController.visibleSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine,
            maximumWidth: 96
        )

        XCTAssertEqual(segments.map(\.kind), [.caffeine, .trigger])
        XCTAssertLessThanOrEqual(MenuBarStatusContentView.preferredWidth(for: segments), 96)
    }

    func testCompactCpuMemorySegmentsStackIntoNarrowChip() {
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%").valueOnlyMenuBarSegment()
        let memory = makeStatusSegment(kind: .memory, value: "90.0%").valueOnlyMenuBarSegment()
        let stackedWidth = MenuBarStatusContentView.preferredWidth(for: [cpu, memory])
        let separatedWidth = MenuBarStatusContentView.preferredWidth(for: [cpu])
            + MenuBarStatusContentView.preferredWidth(for: [memory])

        XCTAssertLessThan(stackedWidth, separatedWidth)
        XCTAssertLessThan(stackedWidth, 60)
    }

    func testCompactCpuMemoryStackHitTestingSplitsRows() {
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%").valueOnlyMenuBarSegment()
        let memory = makeStatusSegment(kind: .memory, value: "90.0%").valueOnlyMenuBarSegment()
        let segments = [cpu, memory]
        let chipCenterX = MenuBarStatusContentView.preferredWidth(for: segments) / 2

        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: chipCenterX, y: 17), in: segments),
            .cpu
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: chipCenterX, y: 5), in: segments),
            .memory
        )
    }

    func testStackedLayoutRendersTitleOverValueChips() {
        let cpu = makeStatusSegment(kind: .cpu, value: "5%")
        let memory = makeStatusSegment(kind: .memory, value: "20%")
        let view = MenuBarStatusContentView(segments: [cpu, memory], layoutStyle: .stacked)
        let labels = view.subviews
            .flatMap(\.subviews)
            .compactMap { $0 as? NSTextField }
            .map(\.stringValue)

        XCTAssertEqual(labels, ["CPU", "5%", "RAM", "20%"])
    }

    func testStackedLayoutUsesThemeAdaptiveTitleColor() {
        let cpu = makeStatusSegment(kind: .cpu, value: "5%")
        let memory = makeStatusSegment(kind: .memory, value: "20%")
        let view = MenuBarStatusContentView(segments: [cpu, memory], layoutStyle: .stacked)
        let labels = view.subviews
            .flatMap(\.subviews)
            .compactMap { $0 as? NSTextField }

        XCTAssertEqual(labels[0].textColor, .labelColor)
        XCTAssertEqual(labels[2].textColor, .labelColor)
    }

    func testStackedLayoutUsesSeparateMetricHitTargets() {
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%")
        let memory = makeStatusSegment(kind: .memory, value: "90.0%")
        let segments = [cpu, memory]
        let cpuOnlyWidth = MenuBarStatusContentView.preferredWidth(for: [cpu], layoutStyle: .stacked)

        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: 4, y: 17),
                in: segments,
                layoutStyle: .stacked
            ),
            .cpu
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: 4, y: 5),
                in: segments,
                layoutStyle: .stacked
            ),
            .cpu
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: cpuOnlyWidth + 4, y: 10),
                in: segments,
                layoutStyle: .stacked
            ),
            .memory
        )
    }

    func testStackedLayoutIsNarrowerThanInlineMetrics() {
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%")
        let memory = makeStatusSegment(kind: .memory, value: "90.0%")

        XCTAssertLessThan(
            MenuBarStatusContentView.preferredWidth(for: [cpu, memory], layoutStyle: .stacked),
            MenuBarStatusContentView.preferredWidth(for: [cpu, memory], layoutStyle: .inline)
        )
    }

    func testDropTriggerUsesSystemSymbolFallback() {
        let image = MenuBarTriggerIconRenderer.image(
            style: .spill,
            tintColor: .systemTeal,
            usageRatio: 0.4,
            size: 18
        )

        XCTAssertNil(image)
    }

    private func makeTriggerSegment() -> MenuBarStatusSegment {
        MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
    }

    private func makeCaffeineSegment(value: String = "", active: Bool = false) -> MenuBarStatusSegment {
        MenuBarStatusSegment(
            kind: .caffeine,
            title: "Caffeine",
            shortTitle: "CAF",
            value: value,
            displayText: value,
            usageRatio: 0,
            state: active ? .active : .unavailable,
            symbolName: active ? "cup.and.saucer.fill" : "cup.and.saucer"
        )
    }

    private func makeStatusSegment(
        kind: MenuBarStatusSegment.Kind,
        value: String
    ) -> MenuBarStatusSegment {
        let title: String
        let shortTitle: String
        let symbolName: String

        switch kind {
        case .cpu:
            title = "CPU"
            shortTitle = "CPU"
            symbolName = "cpu"
        case .memory:
            title = "Memory"
            shortTitle = "MEM"
            symbolName = "memorychip"
        case .caffeine:
            title = "Caffeine"
            shortTitle = "CAF"
            symbolName = "cup.and.saucer"
        case .sleepGuard:
            title = "Sleep Guard"
            shortTitle = "Sleep"
            symbolName = "moon"
        case .trigger:
            title = "Spill"
            shortTitle = "Spill"
            symbolName = "drop.fill"
        }

        return MenuBarStatusSegment(
            kind: kind,
            title: title,
            shortTitle: shortTitle,
            value: value,
            displayText: value,
            usageRatio: 0,
            state: .normal,
            symbolName: symbolName
        )
    }
}
