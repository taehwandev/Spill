import XCTest
@testable import Spill

final class SpillStatusDetailRowsTests: XCTestCase {
    func testAIRowsDoNotExposeMenuBarSummary() {
        let rows = SpillStatusDetailRows.rows(
            for: LocalAIToolStatus(
                kind: .codex,
                value: "Live",
                subtitle: "Process Found",
                state: .active
            )
        )

        XCTAssertEqual(rows.map(\.label), ["Status", "Detail"])
        XCTAssertEqual(rows.map(\.value), ["Live", "Process Found"])
    }
}
