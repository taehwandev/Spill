import AppKit
import XCTest
@testable import Spill

@MainActor
final class StatusItemClickInteractionTests: XCTestCase {
    private let statusWindowFrame = NSRect(x: 1200, y: 980, width: 120, height: 24)

    func testRefreshIsNotDeferredWhenNoMouseButtonIsPressed() {
        XCTAssertFalse(
            StatusItemController.isMouseInteracting(
                pressedMouseButtons: 0,
                mouseLocation: NSPoint(x: 1210, y: 990),
                statusWindowFrames: [statusWindowFrame]
            )
        )
    }

    func testRefreshIsDeferredWhilePressingInsideStatusWindow() {
        XCTAssertTrue(
            StatusItemController.isMouseInteracting(
                pressedMouseButtons: 1,
                mouseLocation: NSPoint(x: 1210, y: 990),
                statusWindowFrames: [statusWindowFrame]
            )
        )
    }

    func testRefreshIsNotDeferredWhilePressingOutsideStatusWindows() {
        XCTAssertFalse(
            StatusItemController.isMouseInteracting(
                pressedMouseButtons: 1,
                mouseLocation: NSPoint(x: 400, y: 400),
                statusWindowFrames: [statusWindowFrame]
            )
        )
    }

    func testRefreshIsNotDeferredWithoutStatusWindows() {
        XCTAssertFalse(
            StatusItemController.isMouseInteracting(
                pressedMouseButtons: 1,
                mouseLocation: NSPoint(x: 1210, y: 990),
                statusWindowFrames: []
            )
        )
    }
}

@MainActor
final class SpillPanelDismissDecisionTests: XCTestCase {
    private func makePanel() -> NSPanel {
        NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
    }

    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
    }

    func testClickInsidePanelDoesNotDismiss() {
        let panel = makePanel()
        XCTAssertFalse(
            SpillPanelDismissController.shouldDismiss(
                forEventWindow: panel,
                panel: panel,
                isExcludedWindow: { _ in false }
            )
        )
    }

    func testClickInExcludedStatusWindowDoesNotDismiss() {
        let panel = makePanel()
        let statusWindow = makeWindow()
        XCTAssertFalse(
            SpillPanelDismissController.shouldDismiss(
                forEventWindow: statusWindow,
                panel: panel,
                isExcludedWindow: { $0 === statusWindow }
            )
        )
    }

    func testClickInUnrelatedWindowDismisses() {
        let panel = makePanel()
        let otherWindow = makeWindow()
        XCTAssertTrue(
            SpillPanelDismissController.shouldDismiss(
                forEventWindow: otherWindow,
                panel: panel,
                isExcludedWindow: { _ in false }
            )
        )
    }

    func testClickInPanelChildWindowDoesNotDismiss() {
        let panel = makePanel()
        let child = makeWindow()
        panel.addChildWindow(child, ordered: .above)
        XCTAssertFalse(
            SpillPanelDismissController.shouldDismiss(
                forEventWindow: child,
                panel: panel,
                isExcludedWindow: { _ in false }
            )
        )
    }
}
