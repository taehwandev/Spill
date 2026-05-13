import XCTest
@testable import Spill

final class SpillProviderModelsTests: XCTestCase {
    func testStatusItemDefaultsToNormalState() {
        let item = SpillStatusItem(
            id: "memory",
            providerID: SpillProviderID(rawValue: "system"),
            title: "Memory",
            value: "42%",
            symbolName: "memorychip"
        )

        XCTAssertEqual(item.id, "memory")
        XCTAssertEqual(item.providerID.rawValue, "system")
        XCTAssertEqual(item.stableKey, "system:memory")
        XCTAssertEqual(item.state, .normal)
        XCTAssertEqual(item.symbolName, "memorychip")
    }

    func testActionKeepsKindAndDefaultState() {
        let action = SpillAction(
            id: "window.left",
            title: "Left",
            symbolName: "rectangle.leadinghalf.inset.filled",
            kind: .window(.leftHalf)
        )

        XCTAssertEqual(action.kind, .window(.leftHalf))
        XCTAssertEqual(action.role, .primary)
        XCTAssertEqual(action.state, .enabled)
    }

    func testStatusItemCanCarryPlainActions() {
        let action = SpillAction(
            id: "open",
            title: "Open",
            kind: .app(bundleIdentifier: "com.example.App")
        )
        let item = SpillStatusItem(
            id: "example",
            providerID: SpillProviderID(rawValue: "apps"),
            title: "Example",
            value: "Ready",
            actions: [action]
        )

        XCTAssertEqual(item.actions, [action])
    }

    func testActionStatesAreHashable() {
        let states: Set<SpillActionState> = [
            .enabled,
            .disabled(reason: "No focused window"),
            .permissionRequired("Accessibility")
        ]

        XCTAssertTrue(states.contains(.enabled))
        XCTAssertTrue(states.contains(.disabled(reason: "No focused window")))
        XCTAssertTrue(states.contains(.permissionRequired("Accessibility")))
    }

    func testActionResultCarriesFailureMessage() {
        let result = SpillActionResult.failed(message: "AXPress failed")

        XCTAssertEqual(result, .failed(message: "AXPress failed"))
    }
}
