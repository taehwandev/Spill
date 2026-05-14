import CoreGraphics
import Foundation
import XCTest
@testable import Spill

final class MenuBarActionAdapterTests: XCTestCase {
    func testEnabledNotchSnapshotMapsToPrimaryAction() {
        let snapshot = makeSnapshot(
            id: "123:com.example.Status:Example:Sync:100:0:24:22",
            stableKey: "com.example.Status::Sync::AXMenuBarItem::",
            title: "Sync",
            imageData: Data([1, 2, 3]),
            isNotchCandidate: true,
            canPress: true
        )

        let action = MenuBarActionAdapter.action(from: snapshot)

        XCTAssertEqual(MenuBarActionAdapter.providerID.rawValue, "menu-bar")
        XCTAssertEqual(action.id, "menu-bar:\(snapshot.id)")
        XCTAssertEqual(MenuBarActionAdapter.sourceSnapshotID(for: action), snapshot.id)
        XCTAssertEqual(action.title, "Sync")
        XCTAssertEqual(action.subtitle, "Example")
        XCTAssertEqual(action.iconData, Data([1, 2, 3]))
        XCTAssertNil(action.symbolName)
        XCTAssertEqual(action.kind, .menuBarItem(stableKey: snapshot.stableKey))
        XCTAssertEqual(action.role, .primary)
        XCTAssertEqual(action.state, .enabled)
        XCTAssertTrue(action.state.isEnabled)
        XCTAssertNil(action.state.disabledReason)
    }

    func testSnapshotWithoutTitleUsesOwnerNameAndFallbackSymbol() {
        let snapshot = makeSnapshot(title: "", imageData: nil)

        let action = MenuBarActionAdapter.action(from: snapshot)

        XCTAssertEqual(action.title, "Example")
        XCTAssertEqual(action.subtitle, "Example")
        XCTAssertEqual(action.symbolName, "app.dashed")
        XCTAssertNil(action.iconData)
    }

    func testNonPressableSnapshotMapsToDisabledSecondaryAction() {
        let snapshot = makeSnapshot(
            isNotchCandidate: false,
            canPress: false
        )

        let action = MenuBarActionAdapter.action(from: snapshot)

        XCTAssertEqual(action.role, .secondary)
        XCTAssertEqual(action.state, .disabled(reason: "Menu bar item cannot be pressed"))
        XCTAssertFalse(action.state.isEnabled)
        XCTAssertEqual(action.state.disabledReason, "Menu bar item cannot be pressed")
    }

    func testActionsPreserveSnapshotOrder() {
        let first = makeSnapshot(id: "first", title: "First")
        let second = makeSnapshot(id: "second", title: "Second")

        let actions = MenuBarActionAdapter.actions(from: [first, second])

        XCTAssertEqual(actions.map(\.title), ["First", "Second"])
        XCTAssertEqual(actions.compactMap(MenuBarActionAdapter.sourceSnapshotID), ["first", "second"])
    }

    func testSourceSnapshotIDRejectsNonMenuBarAction() {
        let action = SpillAction(
            id: "window.left",
            title: "Left",
            kind: .window(.leftHalf)
        )

        XCTAssertNil(MenuBarActionAdapter.sourceSnapshotID(for: action))
    }

    private func makeSnapshot(
        id: String = "123:com.example.Status:Example:Example:100:0:24:22",
        stableKey: String = "com.example.Status::Example::AXMenuBarItem::",
        title: String = "Example",
        imageData: Data? = nil,
        isNotchCandidate: Bool = true,
        canPress: Bool = true
    ) -> MenuBarItemSnapshot {
        MenuBarItemSnapshot(
            id: id,
            stableKey: stableKey,
            ownerName: "Example",
            bundleIdentifier: "com.example.Status",
            processIdentifier: 123,
            title: title,
            role: "AXMenuBarItem",
            subrole: nil,
            frame: CGRect(x: 100, y: 0, width: 24, height: 22),
            imageData: imageData,
            isNotchCandidate: isNotchCandidate,
            canPress: canPress
        )
    }
}
