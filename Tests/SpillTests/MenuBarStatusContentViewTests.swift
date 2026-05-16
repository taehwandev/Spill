import AppKit
import XCTest
@testable import Spill

@MainActor
final class MenuBarStatusContentViewTests: XCTestCase {
    func testSegmentHitTestingFindsCaffeineChip() {
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

        let caffeineOnlyWidth = MenuBarStatusContentView.preferredWidth(for: [caffeine])

        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: 4, y: 10), in: [caffeine, cpu]),
            .caffeine
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: caffeineOnlyWidth + 4, y: 10),
                in: [caffeine, cpu]
            ),
            .cpu
        )
        XCTAssertNil(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: 9_999, y: 10), in: [caffeine, cpu])
        )
    }
}
