import AppKit
import XCTest
@testable import Spill

final class SpillGlanceLayoutTests: XCTestCase {
    func testContentSizeHugsItemsAndNeverExceedsStatusBarHeight() {
        let compact = SpillGlanceLayout.contentSize(itemWidths: [96])
        let expanded = SpillGlanceLayout.contentSize(itemWidths: [96, 124, 88])
        let oversizedHeight = SpillGlanceLayout.contentSize(itemWidths: [96], height: 80)

        XCTAssertEqual(compact.width, 96, accuracy: 0.001)
        XCTAssertEqual(
            expanded.width,
            96 + 124 + 88 + (2 * SpillGlanceLayout.separatorWidth),
            accuracy: 0.001
        )
        XCTAssertGreaterThan(expanded.width, compact.width)
        XCTAssertLessThanOrEqual(compact.height, 34)
        XCTAssertLessThanOrEqual(expanded.height, 34)
        XCTAssertEqual(oversizedHeight.height, 34, accuracy: 0.001)
    }

    func testDefaultTopGapIsTenPoints() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let frame = SpillGlanceLayout.panelFrame(
            contentSize: NSSize(width: 360, height: 32),
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(SpillGlanceLayout.topInset, 10, accuracy: 0.001)
        XCTAssertEqual(visibleFrame.maxY - frame.maxY, 10, accuracy: 0.001)
    }

    func testTokenStripUsesCompactFixedWidthsAndTrailingSettingsControl() {
        let modules = SpillGlanceModule.defaultOrder
        let size = SpillGlanceLayout.contentSize(modules: modules)
        let itemWidth = modules
            .map(SpillGlanceLayout.itemWidth(for:))
            .reduce(0, +)
        let separatorWidth = CGFloat(modules.count) * SpillGlanceLayout.separatorWidth

        XCTAssertEqual(SpillGlanceLayout.contentHeight, 30, accuracy: 0.001)
        XCTAssertEqual(SpillGlanceLayout.settingsControlWidth, 28, accuracy: 0.001)
        XCTAssertEqual(
            SpillGlanceLayout.itemWidth(for: .codexToday),
            SpillGlanceLayout.itemWidth(for: .claudeToday),
            accuracy: 0.001
        )
        XCTAssertEqual(
            SpillGlanceLayout.itemWidth(for: .claudeToday),
            SpillGlanceLayout.itemWidth(for: .antigravityToday),
            accuracy: 0.001
        )
        XCTAssertEqual(
            size.width,
            itemWidth + SpillGlanceLayout.settingsControlWidth + separatorWidth,
            accuracy: 0.001
        )
        XCTAssertLessThan(size.width, 400)
        XCTAssertLessThan(
            SpillGlanceLayout.contentSize(modules: [.allToday, .workType]).width,
            220
        )
        XCTAssertEqual(SpillGlanceLayout.contentSize(modules: []), .zero)
    }

    func testPanelFrameCentersInsideOffsetVisibleFrameAndStaysBelowTopEdge() {
        let visibleFrame = NSRect(x: -1_920, y: 40, width: 1_920, height: 1_040)
        let contentSize = NSSize(width: 360, height: 34)

        let frame = SpillGlanceLayout.panelFrame(
            contentSize: contentSize,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.midX, visibleFrame.midX, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, visibleFrame.maxY - 10, accuracy: 0.001)
        XCTAssertEqual(frame.size, contentSize)
        XCTAssertGreaterThanOrEqual(frame.minX, visibleFrame.minX)
        XCTAssertLessThanOrEqual(frame.maxX, visibleFrame.maxX)
    }

    func testPanelFrameClampsOversizedContentWithinVisibleFrame() {
        let visibleFrame = NSRect(x: 200, y: 100, width: 300, height: 120)
        let frame = SpillGlanceLayout.panelFrame(
            contentSize: NSSize(width: 900, height: 80),
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.midX, visibleFrame.midX, accuracy: 0.001)
        XCTAssertLessThanOrEqual(frame.width, visibleFrame.width)
        XCTAssertLessThanOrEqual(frame.height, 34)
        XCTAssertLessThanOrEqual(frame.maxY, visibleFrame.maxY)
        XCTAssertGreaterThanOrEqual(frame.minY, visibleFrame.minY)
    }

    func testDraggedFrameFollowsAbsoluteAppKitScreenPointer() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let initialFrame = NSRect(x: 500, y: 700, width: 360, height: 32)
        let initialPointer = NSPoint(x: 620, y: 716)
        let currentPointer = NSPoint(x: 668, y: 691)

        let frame = SpillGlanceLayout.draggedFrame(
            initialFrame: initialFrame,
            initialPointerLocation: initialPointer,
            currentPointerLocation: currentPointer,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.minX, initialFrame.minX + 48, accuracy: 0.001)
        XCTAssertEqual(frame.minY, initialFrame.minY - 25, accuracy: 0.001)
    }

    func testDraggedFrameClampsEveryEdgeToVisibleFrame() {
        let visibleFrame = NSRect(x: -800, y: 40, width: 800, height: 560)
        let initialFrame = NSRect(x: -500, y: 300, width: 360, height: 32)

        let beyondTopLeft = SpillGlanceLayout.draggedFrame(
            initialFrame: initialFrame,
            initialPointerLocation: NSPoint(x: 0, y: 0),
            currentPointerLocation: NSPoint(x: -2_000, y: 2_000),
            visibleFrame: visibleFrame
        )
        let beyondBottomRight = SpillGlanceLayout.draggedFrame(
            initialFrame: initialFrame,
            initialPointerLocation: NSPoint(x: 0, y: 0),
            currentPointerLocation: NSPoint(x: 2_000, y: -2_000),
            visibleFrame: visibleFrame
        )

        assertInsideVisibleFrame(beyondTopLeft, visibleFrame: visibleFrame)
        assertInsideVisibleFrame(beyondBottomRight, visibleFrame: visibleFrame)
    }

    func testConstrainedFrameKeepsPersistedFrameInsideChangedScreenGeometry() {
        let visibleFrame = NSRect(x: 300, y: 80, width: 620, height: 360)
        let staleFrame = NSRect(x: -1_900, y: 1_200, width: 360, height: 32)

        let constrained = SpillGlanceLayout.constrainedFrame(
            staleFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(constrained.size, staleFrame.size)
        assertInsideVisibleFrame(constrained, visibleFrame: visibleFrame)
    }

    func testFrameStorePersistsAndRestoresWithoutOpeningAWindow() throws {
        let suiteName = "SpillGlanceFrameStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let visibleFrame = NSRect(x: 0, y: 40, width: 1_440, height: 860)
        let fallback = NSRect(x: 540, y: 862, width: 360, height: 32)
        let savedFrame = NSRect(x: 84, y: 118, width: 360, height: 32)

        let initialStore = SpillGlanceFrameStore(defaults: defaults)
        XCTAssertEqual(
            initialStore.restoredFrame(visibleFrame: visibleFrame, fallback: fallback),
            fallback
        )

        initialStore.save(savedFrame)

        let restoredStore = SpillGlanceFrameStore(defaults: defaults)
        XCTAssertEqual(
            restoredStore.restoredFrame(visibleFrame: visibleFrame, fallback: fallback),
            savedFrame
        )
    }

    func testFrameStoreRestoresOnConnectedDisplayContainingSavedPosition() throws {
        let suiteName = "SpillGlanceFrameStoreConnectedDisplayTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let primaryVisibleFrame = NSRect(x: 0, y: 40, width: 1_440, height: 860)
        let externalVisibleFrame = NSRect(x: 1_440, y: 0, width: 1_920, height: 1_080)
        let fallback = NSRect(x: 540, y: 858, width: 360, height: 32)
        let savedExternalFrame = NSRect(x: 1_800, y: 900, width: 360, height: 32)
        let store = SpillGlanceFrameStore(defaults: defaults)
        store.save(savedExternalFrame)

        let restored = store.restoredFrame(
            visibleFrames: [primaryVisibleFrame, externalVisibleFrame],
            fallback: fallback
        )

        XCTAssertEqual(restored, savedExternalFrame)
    }

    func testFrameStoreFallsBackWhileSavedDisplayIsDisconnected() throws {
        let suiteName = "SpillGlanceFrameStoreDisconnectedDisplayTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let primaryVisibleFrame = NSRect(x: 0, y: 40, width: 1_440, height: 860)
        let externalVisibleFrame = NSRect(x: 1_440, y: 0, width: 1_920, height: 1_080)
        let fallback = NSRect(x: 540, y: 858, width: 360, height: 32)
        let savedExternalFrame = NSRect(x: 1_800, y: 900, width: 360, height: 32)
        let store = SpillGlanceFrameStore(defaults: defaults)
        store.save(savedExternalFrame)

        XCTAssertEqual(
            store.restoredFrame(
                visibleFrames: [primaryVisibleFrame],
                fallback: fallback
            ),
            fallback
        )
        XCTAssertEqual(
            store.restoredFrame(
                visibleFrames: [primaryVisibleFrame, externalVisibleFrame],
                fallback: fallback
            ),
            savedExternalFrame,
            "A temporary fallback must not overwrite the user's external-display position."
        )
    }
}

private extension SpillGlanceLayoutTests {
    func assertInsideVisibleFrame(
        _ frame: NSRect,
        visibleFrame: NSRect,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(
            frame.minX,
            visibleFrame.minX,
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(
            frame.maxX,
            visibleFrame.maxX,
            file: file,
            line: line
        )
        XCTAssertGreaterThanOrEqual(
            frame.minY,
            visibleFrame.minY,
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(
            frame.maxY,
            visibleFrame.maxY,
            file: file,
            line: line
        )
    }
}
