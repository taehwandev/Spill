import Foundation
import XCTest

final class SpillGlancePanelSourceTests: XCTestCase {
    func testPanelUsesNonactivatingWindowAndSpaceBehaviors() throws {
        let source = try glanceSource()

        XCTAssertTrue(
            source.contains(".nonactivatingPanel"),
            "Spill Glance must never take focus from the user's active app."
        )
        XCTAssertTrue(
            source.contains(".canJoinAllSpaces"),
            "The always-visible Glance surface must follow the user across Spaces."
        )
        XCTAssertTrue(
            source.contains(".fullScreenAuxiliary"),
            "The Glance panel must be eligible to appear alongside full-screen apps."
        )
        XCTAssertTrue(
            source.contains("canBecomeKey") && source.contains("canBecomeMain"),
            "The panel subclass must explicitly document that it cannot become key or main."
        )
        XCTAssertTrue(
            source.matches(#"canBecomeKey[^}]*\{\s*false\s*\}"#),
            "The panel must explicitly return false from canBecomeKey."
        )
        XCTAssertTrue(
            source.matches(#"canBecomeMain[^}]*\{\s*false\s*\}"#),
            "The panel must explicitly return false from canBecomeMain."
        )
    }

    func testGlanceBoundaryAddsNoIndependentPollingOrNetworkSource() throws {
        let source = try glanceSource()
        let forbiddenSources = [
            "Timer(",
            "Timer.publish",
            "scheduledTimer",
            "DispatchSource.makeTimerSource",
            "URLSession",
            "NWPathMonitor",
            "Network.framework",
        ]

        for forbiddenSource in forbiddenSources {
            XCTAssertFalse(
                source.contains(forbiddenSource),
                "Spill Glance must reuse existing publishers instead of adding \(forbiddenSource)."
            )
        }
        XCTAssertFalse(
            source.contains("AIStatusStore"),
            "The token strip should not depend on process activity after removing the active-count module."
        )
    }

    func testModulesShareOneGroupedGlassSurface() throws {
        let source = try source(at: "Sources/Spill/Glance/SpillGlanceView.swift")

        XCTAssertTrue(source.contains("ForEach(Array(items.enumerated())"))
        XCTAssertTrue(source.contains("SpillGlanceSurface"))
        XCTAssertTrue(source.contains("SpillGlanceModuleContent"))
        XCTAssertFalse(
            source.contains("SpillGlanceCapsule"),
            "Modules should be cells inside one glass bar, not independent material capsules."
        )
        XCTAssertEqual(
            source.occurrenceCount(of: ".ultraThinMaterial"),
            1,
            "The Glance row should apply material once around the grouped module content."
        )
    }

    func testSurfaceDragMovesThroughControllerAndPersistsTheConstrainedFrame() throws {
        let viewSource = try source(at: "Sources/Spill/Glance/SpillGlanceView.swift")
        let controllerSource = try source(
            at: "Sources/Spill/Glance/SpillGlancePanelController.swift"
        )
        let allSource = try glanceSource()

        XCTAssertTrue(
            viewSource.contains("DragGesture"),
            "The grouped surface should expose direct drag positioning."
        )
        XCTAssertTrue(
            viewSource.contains("SpillGlanceDragPhase"),
            "Drag translation should be injected into the view instead of moving AppKit state directly."
        )
        XCTAssertTrue(
            allSource.contains("SpillGlanceFrameStore"),
            "Glance movement needs a dedicated, injectable persistence boundary."
        )
        XCTAssertTrue(
            controllerSource.contains("frameStore.save"),
            "The controller must persist the final constrained frame after a drag ends."
        )
        XCTAssertTrue(
            controllerSource.contains("NSEvent.mouseLocation"),
            "Window movement should follow the absolute screen pointer instead of a moving view's coordinates."
        )
        XCTAssertTrue(
            controllerSource.contains("setFrameOrigin"),
            "A live drag should move the composited window origin without redrawing unchanged glass content."
        )
        XCTAssertFalse(
            controllerSource.contains("display: true"),
            "Dragging a transparent glass panel must not force a full content redraw for every pointer event."
        )
        XCTAssertTrue(
            controllerSource.contains("NSScreen.screens.first")
                && controllerSource.contains("NSMouseInRect"),
            "The controller should select the connected display under the absolute pointer."
        )
    }

    func testSurfaceRoutesItsPrimaryInteractionToInjectedDashboardAction() throws {
        let viewSource = try source(at: "Sources/Spill/Glance/SpillGlanceView.swift")
        let controllerSource = try source(
            at: "Sources/Spill/Glance/SpillGlancePanelController.swift"
        )
        let appDelegateSource = try source(at: "Sources/Spill/App/AppDelegate.swift")

        XCTAssertTrue(viewSource.contains("openDashboardAction"))
        XCTAssertTrue(
            viewSource.contains("if didDrag") && viewSource.contains("openDashboardAction()"),
            "The grouped surface should open the dashboard only when the pointer interaction was a tap."
        )
        XCTAssertTrue(viewSource.contains("openSettingsAction"))
        XCTAssertTrue(viewSource.contains("isSettingsLocation"))
        XCTAssertTrue(controllerSource.contains("openSettingsAction"))
        XCTAssertTrue(
            appDelegateSource.contains(#"selectedTab: "glance""#),
            "The trailing settings segment must open the dedicated Spill Glance destination."
        )
    }

    func testSurfaceAvoidsLayeredTintAndHoverScaleEffects() throws {
        let source = try source(at: "Sources/Spill/Glance/SpillGlanceView.swift")

        XCTAssertFalse(source.contains("fallbackTint"))
        XCTAssertFalse(source.contains(".scaleEffect"))
        XCTAssertFalse(source.contains(".tint(groupTint"))
        XCTAssertTrue(source.contains(".clipShape(Capsule"))
    }

    func testOptionalToolsUseColorCodedIconValuesWithoutVisibleNames() throws {
        let viewSource = try source(at: "Sources/Spill/Glance/SpillGlanceView.swift")
        let tintSource = try source(at: "Sources/Spill/Glance/SpillGlanceTint.swift")

        XCTAssertTrue(viewSource.contains("if !item.module.isTool"))
        XCTAssertTrue(tintSource.contains("TokenUsageAITool.codex.dashboardTint"))
        XCTAssertTrue(tintSource.contains("TokenUsageAITool.claude.dashboardTint"))
        XCTAssertTrue(tintSource.contains("TokenUsageAITool.antigravity.dashboardTint"))
    }

    func testWorkTypeUsesBoundedPresentationOnlyRollingSchedule() throws {
        let viewSource = try source(at: "Sources/Spill/Glance/SpillGlanceView.swift")
        let storeSource = try source(at: "Sources/Spill/Glance/SpillGlanceStore.swift")
        let itemSource = try source(at: "Sources/Spill/Glance/SpillGlanceItem.swift")

        XCTAssertEqual(
            viewSource.occurrenceCount(of: "TimelineView("),
            1,
            "Only the root Glance surface should own the rotating schedule."
        )
        XCTAssertTrue(viewSource.contains("if let workRotationEpoch"))
        XCTAssertTrue(
            viewSource.contains("$0.module == .workType && $0.displayValues.count > 1"),
            "The root schedule should exist only while Work has multiple values to rotate."
        )
        XCTAssertTrue(viewSource.contains("SpillGlanceItem.rotationInterval"))
        XCTAssertTrue(viewSource.contains("SpillGlanceSurface(items: store.presentation.items, date: date)"))
        XCTAssertTrue(viewSource.contains(".accessibilityLabel(accessibilityLabel(at: date))"))
        XCTAssertTrue(viewSource.contains("$0.displayValue(at: date)"))
        XCTAssertTrue(storeSource.contains("$glanceWorkRotationEnabled"))
        XCTAssertTrue(storeSource.contains("nextRotationIdentity != workRotationIdentity"))
        XCTAssertTrue(storeSource.contains("workRotationEpoch = now()"))
        XCTAssertTrue(itemSource.contains("date.timeIntervalSince(rotationEpoch)"))
        XCTAssertFalse(itemSource.contains("timeIntervalSinceReferenceDate / interval"))
        XCTAssertFalse(viewSource.contains("Timer("))
        XCTAssertFalse(viewSource.contains("scheduledTimer"))
    }

    func testGlanceConsumesUnfilteredCurrentDaySummary() throws {
        let storeSource = try source(at: "Sources/Spill/Glance/SpillGlanceStore.swift")

        XCTAssertTrue(storeSource.contains("tokenUsageDashboardStore.glanceSummary"))
        XCTAssertTrue(storeSource.contains("tokenUsageDashboardStore.$glanceSummary"))
        XCTAssertFalse(storeSource.contains("tokenUsageDashboardStore.panelSummary"))
        XCTAssertFalse(storeSource.contains("tokenUsageDashboardStore.$panelSummary"))
    }

    func testPresentationUpdatesWaitForCommittedStateAndDoNotReframeContentChanges() throws {
        let controllerSource = try source(
            at: "Sources/Spill/Glance/SpillGlancePanelController.swift"
        )

        XCTAssertTrue(
            controllerSource.contains(".receive(on: DispatchQueue.main)"),
            """
            The AppKit controller must consume @Published presentation changes after the
            new value commits, so SwiftUI never redraws the previous rolling value.
            """
        )
        XCTAssertTrue(
            controllerSource.contains(".dropFirst()"),
            "The explicit initial render should not also enqueue a duplicate presentation update."
        )
        XCTAssertTrue(
            controllerSource.contains("presentedModules != modules"),
            """
            Token or rotation-value changes must not reapply the saved window frame.
            Only an ordered module-layout change should resize or reposition the panel.
            """
        )
    }

    func testPanelPlatformObjectsKeepOneTopLevelOwnerPerSourceFile() throws {
        let panelSource = try source(at: "Sources/Spill/Glance/SpillGlancePanel.swift")
        let hostingSource = try source(
            at: "Sources/Spill/Glance/SpillGlanceHostingView.swift"
        )
        let storeSource = try source(at: "Sources/Spill/Glance/SpillGlanceStore.swift")
        let rotationIdentitySource = try source(
            at: "Sources/Spill/Glance/SpillGlanceWorkRotationIdentity.swift"
        )

        XCTAssertTrue(panelSource.contains("final class SpillGlancePanel: NSPanel"))
        XCTAssertFalse(panelSource.contains("SpillGlanceHostingView"))
        XCTAssertTrue(hostingSource.contains("final class SpillGlanceHostingView"))
        XCTAssertFalse(hostingSource.contains("final class SpillGlancePanel: NSPanel"))
        XCTAssertTrue(storeSource.contains("final class SpillGlanceStore: ObservableObject"))
        XCTAssertFalse(storeSource.contains("struct SpillGlanceWorkRotationIdentity"))
        XCTAssertTrue(
            rotationIdentitySource.contains("struct SpillGlanceWorkRotationIdentity: Equatable")
        )
        XCTAssertFalse(rotationIdentitySource.contains("final class SpillGlanceStore"))
    }
}

private extension SpillGlancePanelSourceTests {
    func source(at relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    func glanceSource() throws -> String {
        let glanceDirectory = repositoryRoot.appendingPathComponent(
            "Sources/Spill/Glance",
            isDirectory: true
        )
        let sourceURLs = try FileManager.default.contentsOfDirectory(
            at: glanceDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "swift" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertFalse(sourceURLs.isEmpty, "The Glance source boundary should contain Swift files.")
        return try sourceURLs
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }

    var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private extension String {
    func matches(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }

    func occurrenceCount(of needle: String) -> Int {
        components(separatedBy: needle).count - 1
    }
}
