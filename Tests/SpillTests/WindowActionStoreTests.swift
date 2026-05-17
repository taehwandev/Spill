import CoreGraphics
import XCTest
@testable import Spill

@MainActor
final class WindowActionStoreTests: XCTestCase {
    func testInitializationDoesNotReadFocusedWindow() {
        let controller = FakeFocusedWindowController()
        _ = WindowActionStore(
            controller: controller,
            isAccessibilityTrusted: { true }
        )

        XCTAssertEqual(controller.focusedWindowFrameCallCount, 0)
        XCTAssertEqual(controller.performCallCount, 0)
    }

    func testRefreshSkipsFocusedWindowLookupWhenAccessibilityIsUntrusted() {
        let controller = FakeFocusedWindowController()
        let store = WindowActionStore(
            controller: controller,
            isAccessibilityTrusted: { false }
        )

        store.refresh()

        XCTAssertEqual(controller.focusedWindowFrameCallCount, 0)
        XCTAssertTrue(store.actions.allSatisfy { action in
            if case .permissionRequired("Accessibility") = action.state {
                return true
            }

            return false
        })
    }

    func testRefreshReadsFocusedWindowOnlyWhenAccessibilityIsTrusted() {
        let controller = FakeFocusedWindowController()
        controller.focusedFrame = CGRect(x: 10, y: 10, width: 400, height: 300)
        let store = WindowActionStore(
            controller: controller,
            isAccessibilityTrusted: { true }
        )

        store.refresh()

        XCTAssertEqual(controller.focusedWindowFrameCallCount, 1)
        XCTAssertEqual(store.actions.first { $0.kind == .window(.leftHalf) }?.state, .enabled)
    }

    func testPerformSkipsControllerWhenAccessibilityIsUntrusted() {
        let controller = FakeFocusedWindowController()
        let store = WindowActionStore(
            controller: controller,
            isAccessibilityTrusted: { false }
        )

        let result = store.perform(.leftHalf)

        XCTAssertEqual(result, .permissionRequired("Accessibility"))
        XCTAssertEqual(controller.performCallCount, 0)
        XCTAssertEqual(controller.focusedWindowFrameCallCount, 0)
    }
}

@MainActor
private final class FakeFocusedWindowController: FocusedWindowControlling {
    var focusedFrame: CGRect?
    var focusedWindowFrameCallCount = 0
    var performCallCount = 0
    var performResult: SpillActionResult = .success

    func focusedWindowFrame() -> CGRect? {
        focusedWindowFrameCallCount += 1
        return focusedFrame
    }

    func perform(_ kind: WindowActionKind, restoreHistory: inout WindowFrameRestoreHistory) -> SpillActionResult {
        performCallCount += 1
        if performResult == .success {
            restoreHistory.record(CGRect(x: 10, y: 10, width: 400, height: 300))
        }

        return performResult
    }
}
