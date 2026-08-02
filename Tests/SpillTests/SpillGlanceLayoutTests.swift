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
        XCTAssertLessThan(size.width, 640)
        XCTAssertLessThan(
            SpillGlanceLayout.contentSize(modules: [.allToday, .workType]).width,
            320
        )
        XCTAssertEqual(SpillGlanceLayout.contentSize(modules: []), .zero)
    }

    /// Values no longer shrink to fit, so every cell must contain the widest
    /// content it can ever be asked to render, in every shipped language.
    @MainActor
    func testFixedCellWidthsContainTheWidestRenderableContentInEveryLanguage() {
        XCTAssertGreaterThanOrEqual(
            SpillGlanceLayout.itemWidth(for: .allToday),
            fixedContentWidth(label: "All", value: widestTokenValue)
        )
        for module in SpillGlanceModule.configurableToolModules {
            guard let compactTitle = module.compactTitle else {
                return XCTFail("\(module) must define a compact label for the all layout.")
            }
            XCTAssertGreaterThanOrEqual(
                SpillGlanceLayout.itemWidth(for: module),
                fixedContentWidth(label: compactTitle, value: widestTokenValue),
                "\(module) compact cell must fit its own label and value."
            )
        }

        var widestWorkContent: CGFloat = 0
        var widestWorkDescription = ""
        for language in TokenMeteringLanguage.allCases {
            for id in recommendedTaskIDs {
                let title = TokenMeteringL10n.taskLabel(id, language: language)
                let compactTitle = SpillGlanceStore.compactTaskTitle(id: id, title: title)
                let width = fixedContentWidth(
                    label: "Work",
                    value: "\(compactTitle) \(widestTokenValue)"
                )
                guard width > widestWorkContent else {
                    continue
                }
                widestWorkContent = width
                widestWorkDescription = "\(language.rawValue)/\(id) → \"\(compactTitle)\""
            }
        }

        XCTAssertGreaterThanOrEqual(
            SpillGlanceLayout.itemWidth(for: .workType),
            widestWorkContent,
            "Work cell clips \(widestWorkDescription) (needs \(widestWorkContent))."
        )
        // The ticker slot renders full titles, so it also has to fit the widest one.
        let widestTickerContent = max(
            widestWorkContent,
            fixedContentWidth(label: "Claude", value: widestTokenValue)
        )
        XCTAssertGreaterThanOrEqual(
            SpillGlanceLayout.tickerItemWidth,
            widestTickerContent,
            "Ticker slot clips \(widestWorkDescription) (needs \(widestTickerContent))."
        )
    }

    func testTickerContentUsesOneStableFixedWidthSlot() {
        let compact = SpillGlanceLayout.contentSize(
            modules: [.allToday, .workType],
            displayStyle: .ticker
        )
        let expanded = SpillGlanceLayout.contentSize(
            modules: SpillGlanceModule.defaultOrder,
            displayStyle: .ticker
        )

        XCTAssertEqual(compact, expanded)
        XCTAssertEqual(
            compact.width,
            SpillGlanceLayout.tickerItemWidth
                + SpillGlanceLayout.separatorWidth
                + SpillGlanceLayout.settingsControlWidth,
            accuracy: 0.001
        )
        XCTAssertEqual(compact.height, SpillGlanceLayout.contentHeight, accuracy: 0.001)
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

    func testHorizontalDragCanReachTheBottomEdge() {
        let visibleFrame = NSRect(x: 200, y: 80, width: 1_000, height: 700)
        let initialFrame = NSRect(x: 520, y: 600, width: 360, height: 30)

        let bottomFrame = SpillGlanceLayout.draggedFrame(
            initialFrame: initialFrame,
            initialPointerLocation: NSPoint(x: 600, y: 615),
            currentPointerLocation: NSPoint(x: 600, y: -1_000),
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(
            bottomFrame.minY,
            visibleFrame.minY + SpillGlanceLayout.bottomScreenInset,
            accuracy: 0.001
        )
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

        let display = SpillGlanceScreenDescriptor(
            id: "primary",
            visibleFrame: NSRect(x: 0, y: 40, width: 1_440, height: 860)
        )
        let contentSize = NSSize(width: 360, height: 32)
        let savedFrame = NSRect(x: 84, y: 118, width: 360, height: 32)
        let fallback = SpillGlanceLayout.panelFrame(
            contentSize: contentSize,
            visibleFrame: display.visibleFrame
        )

        let initialStore = SpillGlanceFrameStore(defaults: defaults)
        XCTAssertEqual(
            initialStore.restoredFrame(
                displays: [display],
                fallbackDisplay: display,
                contentSize: contentSize
            ),
            fallback
        )

        initialStore.save(savedFrame, display: display)

        let restoredStore = SpillGlanceFrameStore(defaults: defaults)
        XCTAssertEqual(
            restoredStore.restoredFrame(
                displays: [display],
                fallbackDisplay: display,
                contentSize: contentSize
            ),
            savedFrame
        )
    }

    func testFrameStoreRestoresOnConnectedDisplayContainingSavedPosition() throws {
        let suiteName = "SpillGlanceFrameStoreConnectedDisplayTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let primary = SpillGlanceScreenDescriptor(
            id: "primary",
            visibleFrame: NSRect(x: 0, y: 40, width: 1_440, height: 860)
        )
        let external = SpillGlanceScreenDescriptor(
            id: "external",
            visibleFrame: NSRect(x: 1_440, y: 0, width: 1_920, height: 1_080)
        )
        let contentSize = NSSize(width: 360, height: 32)
        let savedExternalFrame = NSRect(x: 1_800, y: 900, width: 360, height: 32)
        let store = SpillGlanceFrameStore(defaults: defaults)
        store.save(savedExternalFrame, display: external)

        let restored = store.restoredFrame(
            displays: [primary, external],
            fallbackDisplay: primary,
            contentSize: contentSize
        )

        XCTAssertEqual(restored, savedExternalFrame)
    }

    func testFrameStoreFallsBackWhileSavedDisplayIsDisconnected() throws {
        let suiteName = "SpillGlanceFrameStoreDisconnectedDisplayTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let primary = SpillGlanceScreenDescriptor(
            id: "primary",
            visibleFrame: NSRect(x: 0, y: 40, width: 1_440, height: 860)
        )
        let external = SpillGlanceScreenDescriptor(
            id: "external",
            visibleFrame: NSRect(x: 1_440, y: 0, width: 1_920, height: 1_080)
        )
        let contentSize = NSSize(width: 360, height: 32)
        let savedExternalFrame = NSRect(x: 1_800, y: 900, width: 360, height: 32)
        let store = SpillGlanceFrameStore(defaults: defaults)
        store.save(savedExternalFrame, display: external)
        let fallbackPlacement = SpillGlancePlacement.capture(
            frame: savedExternalFrame,
            display: external
        ).frame(
            contentSize: contentSize,
            visibleFrame: primary.visibleFrame
        )

        XCTAssertEqual(
            store.restoredFrame(
                displays: [primary],
                fallbackDisplay: primary,
                contentSize: contentSize
            ),
            fallbackPlacement
        )
        XCTAssertEqual(
            store.restoredFrame(
                displays: [primary, external],
                fallbackDisplay: primary,
                contentSize: contentSize
            ),
            savedExternalFrame,
            "A temporary fallback must not overwrite the user's external-display position."
        )
    }

    func testPlacementKeepsRightBottomAnchorAcrossResolutionChanges() throws {
        let suiteName = "SpillGlanceFrameStoreAnchorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let original = SpillGlanceScreenDescriptor(
            id: "same-display",
            visibleFrame: NSRect(x: 0, y: 40, width: 1_440, height: 860)
        )
        let resized = SpillGlanceScreenDescriptor(
            id: "same-display",
            visibleFrame: NSRect(x: 0, y: 24, width: 1_920, height: 1_056)
        )
        let contentSize = NSSize(width: 360, height: 32)
        let savedFrame = NSRect(
            x: original.visibleFrame.maxX - 8 - contentSize.width,
            y: original.visibleFrame.minY + 8,
            width: contentSize.width,
            height: contentSize.height
        )
        let store = SpillGlanceFrameStore(defaults: defaults)
        store.save(savedFrame, display: original)

        let restored = store.restoredFrame(
            displays: [resized],
            fallbackDisplay: resized,
            contentSize: contentSize
        )

        XCTAssertEqual(resized.visibleFrame.maxX - restored.maxX, 8, accuracy: 0.001)
        XCTAssertEqual(restored.minY - resized.visibleFrame.minY, 8, accuracy: 0.001)
    }

    func testFreePlacementKeepsVisibleFrameRatiosAcrossResolutionChanges() {
        let original = SpillGlanceScreenDescriptor(
            id: "display",
            visibleFrame: NSRect(x: 0, y: 40, width: 1_440, height: 860)
        )
        let contentSize = NSSize(width: 360, height: 32)
        let allowedX = SpillGlanceLayout.allowedOriginXRange(
            contentWidth: contentSize.width,
            visibleFrame: original.visibleFrame
        )
        let allowedY = SpillGlanceLayout.allowedOriginYRange(
            contentHeight: contentSize.height,
            visibleFrame: original.visibleFrame
        )
        let frame = NSRect(
            x: allowedX.lowerBound + ((allowedX.upperBound - allowedX.lowerBound) * 0.25),
            y: allowedY.lowerBound + ((allowedY.upperBound - allowedY.lowerBound) * 0.60),
            width: contentSize.width,
            height: contentSize.height
        )
        let placement = SpillGlancePlacement.capture(frame: frame, display: original)
        let resizedFrame = NSRect(x: -1_600, y: 0, width: 1_600, height: 1_000)
        let restored = placement.frame(
            contentSize: contentSize,
            visibleFrame: resizedFrame
        )
        let resizedAllowedX = SpillGlanceLayout.allowedOriginXRange(
            contentWidth: contentSize.width,
            visibleFrame: resizedFrame
        )
        let resizedAllowedY = SpillGlanceLayout.allowedOriginYRange(
            contentHeight: contentSize.height,
            visibleFrame: resizedFrame
        )

        XCTAssertEqual(
            (restored.minX - resizedAllowedX.lowerBound)
                / (resizedAllowedX.upperBound - resizedAllowedX.lowerBound),
            0.25,
            accuracy: 0.001
        )
        XCTAssertEqual(
            (restored.minY - resizedAllowedY.lowerBound)
                / (resizedAllowedY.upperBound - resizedAllowedY.lowerBound),
            0.60,
            accuracy: 0.001
        )
    }

    func testLegacyAbsoluteFrameMigratesWhenDisplayIsConnected() throws {
        let suiteName = "SpillGlanceLegacyFrameMigrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let display = SpillGlanceScreenDescriptor(
            id: "legacy-display",
            visibleFrame: NSRect(x: 0, y: 40, width: 1_440, height: 860)
        )
        let legacyFrame = NSRect(x: 84, y: 118, width: 360, height: 32)
        defaults.set(NSStringFromRect(legacyFrame), forKey: "spillGlanceFrame")
        let store = SpillGlanceFrameStore(defaults: defaults)

        store.migrateLegacyPlacementIfNeeded(displays: [display])
        let restored = store.restoredFrame(
            displays: [display],
            fallbackDisplay: display,
            contentSize: legacyFrame.size
        )

        XCTAssertEqual(restored, legacyFrame)
        XCTAssertNotNil(defaults.data(forKey: "spillGlancePlacementV2"))
        XCTAssertNil(defaults.string(forKey: "spillGlanceFrame"))
    }

    /// Restoring must never write; only the explicit migration step may.
    func testRestoringDoesNotConsumeTheLegacyFrame() throws {
        let suiteName = "SpillGlanceLegacyFrameReadOnlyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let display = SpillGlanceScreenDescriptor(
            id: "legacy-display",
            visibleFrame: NSRect(x: 0, y: 40, width: 1_440, height: 860)
        )
        let legacyFrame = NSRect(x: 84, y: 118, width: 360, height: 32)
        defaults.set(NSStringFromRect(legacyFrame), forKey: "spillGlanceFrame")
        let store = SpillGlanceFrameStore(defaults: defaults)

        _ = store.restoredFrame(
            displays: [display],
            fallbackDisplay: display,
            contentSize: legacyFrame.size
        )

        XCTAssertNil(defaults.data(forKey: "spillGlancePlacementV2"))
        XCTAssertNotNil(defaults.string(forKey: "spillGlanceFrame"))
    }

    /// A disconnected original display must not lose the legacy position.
    func testLegacyFrameSurvivesUntilItsDisplayReconnects() throws {
        let suiteName = "SpillGlanceLegacyFrameDeferredTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let connected = SpillGlanceScreenDescriptor(
            id: "other-display",
            visibleFrame: NSRect(x: 2_000, y: 0, width: 1_920, height: 1_080)
        )
        let original = SpillGlanceScreenDescriptor(
            id: "legacy-display",
            visibleFrame: NSRect(x: 0, y: 40, width: 1_440, height: 860)
        )
        let legacyFrame = NSRect(x: 84, y: 118, width: 360, height: 32)
        defaults.set(NSStringFromRect(legacyFrame), forKey: "spillGlanceFrame")
        let store = SpillGlanceFrameStore(defaults: defaults)

        store.migrateLegacyPlacementIfNeeded(displays: [connected])
        XCTAssertNotNil(defaults.string(forKey: "spillGlanceFrame"))

        store.migrateLegacyPlacementIfNeeded(displays: [connected, original])
        XCTAssertNil(defaults.string(forKey: "spillGlanceFrame"))
        XCTAssertEqual(
            store.restoredFrame(
                displays: [connected, original],
                fallbackDisplay: connected,
                contentSize: legacyFrame.size
            ),
            legacyFrame
        )
    }
}

private extension SpillGlanceLayoutTests {
    /// `formatTokens` never produces anything wider than a saturated `T` value.
    var widestTokenValue: String { "999.99T" }

    var recommendedTaskIDs: [String] {
        [
            "analysis", "prd_drafting", "architecture", "code_generation",
            "ui_design", "prompt_design", "refactoring", "code_review",
            "review_response", "test_generation", "testing", "build_verification",
            "debugging", "bug_reproduction", "documentation", "changelog",
            "release_notes", "release_packaging", "git_commit", "commit_message",
            "pull_request", "workflow_setup", "uncategorized",
        ]
    }

    func fixedContentWidth(label: String, value: String) -> CGFloat {
        let labelFont = roundedSystemFont(size: 9.5, weight: .semibold)
        let valueFont = roundedSystemFont(size: 10, weight: .bold)
        let labelWidth = (label as NSString).size(withAttributes: [.font: labelFont]).width
        let valueWidth = (value as NSString).size(withAttributes: [.font: valueFont]).width
        let iconWidth: CGFloat = 14
        let internalSpacing: CGFloat = 8
        let horizontalPadding: CGFloat = 12
        let safetyMargin: CGFloat = 4
        return ceil(
            iconWidth
                + internalSpacing
                + horizontalPadding
                + labelWidth
                + valueWidth
                + safetyMargin
        )
    }

    func roundedSystemFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded),
              let rounded = NSFont(descriptor: descriptor, size: size)
        else {
            return base
        }
        return rounded
    }

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
