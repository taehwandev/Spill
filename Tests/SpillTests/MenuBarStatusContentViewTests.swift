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

    func testTriggerRendererUsesRequestedMenuBarSize() {
        let image = MenuBarTriggerIconRenderer.image(
            style: .cat,
            tintColor: .systemTeal,
            usageRatio: 0.4,
            size: 18
        )

        XCTAssertEqual(image?.size.width, 18)
        XCTAssertEqual(image?.size.height, 18)
    }

    func testCatTriggerRendererAnimatesTailAcrossPhases() {
        let first = MenuBarTriggerIconRenderer.image(
            style: .cat,
            tintColor: .systemTeal,
            usageRatio: 1,
            phase: 0,
            size: 18
        )?.tiffRepresentation
        let second = MenuBarTriggerIconRenderer.image(
            style: .cat,
            tintColor: .systemTeal,
            usageRatio: 1,
            phase: 0.125,
            size: 18
        )?.tiffRepresentation

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertNotEqual(first, second)
    }
}
