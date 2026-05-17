import AppKit
import XCTest
@testable import Spill

@MainActor
final class MenuBarStatusContentViewTests: XCTestCase {
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

        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: 4, y: 10), in: [trigger, caffeine, cpu]),
            .trigger
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: triggerWidth + 4, y: 10),
                in: [trigger, caffeine, cpu]
            ),
            .caffeine
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: triggerWidth + caffeineOnlyWidth + 4, y: 10),
                in: [trigger, caffeine, cpu]
            ),
            .cpu
        )
        XCTAssertNil(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: 9_999, y: 10), in: [trigger, caffeine, cpu])
        )
    }
}
