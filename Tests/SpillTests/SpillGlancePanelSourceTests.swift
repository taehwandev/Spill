import AppKit
import Foundation
import XCTest
@testable import Spill

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
            "The Glance panel must support the explicit full-screen opt-in."
        )
        XCTAssertTrue(
            source.contains("if showInFullScreen")
                && source.contains("behavior.insert(.fullScreenAuxiliary)"),
            "Full-screen auxiliary behavior must be conditional instead of always on."
        )
        XCTAssertTrue(
            source.contains("behavior.insert(.fullScreenNone)"),
            "The default policy must explicitly exclude native full-screen Spaces."
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

    func testFullScreenPreferenceSelectsMutuallyExclusiveCollectionBehaviors() {
        let excludedBehavior = SpillGlancePanelController.collectionBehavior(
            showInFullScreen: false
        )
        XCTAssertTrue(excludedBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(excludedBehavior.contains(.fullScreenNone))
        XCTAssertFalse(excludedBehavior.contains(.fullScreenAuxiliary))

        let includedBehavior = SpillGlancePanelController.collectionBehavior(
            showInFullScreen: true
        )
        XCTAssertTrue(includedBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(includedBehavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(includedBehavior.contains(.fullScreenNone))
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
            controllerSource.contains("frameStore.save(panel.frame, display: finalDisplay)"),
            "The controller must persist the final constrained frame with its display identity."
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
            allSource.contains("NSScreen.screens.first")
                && allSource.contains("NSMouseInRect"),
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
        XCTAssertTrue(source.contains(".clipShape(surfaceShape)"))
        XCTAssertTrue(source.contains("RoundedRectangle("))
    }

    func testAllModeUsesCompactToolLabelsAndColorCodedIcons() throws {
        let viewSource = try source(at: "Sources/Spill/Glance/SpillGlanceView.swift")
        let tintSource = try source(at: "Sources/Spill/Glance/SpillGlanceTint.swift")
        let moduleSource = try source(at: "Sources/Spill/Settings/SpillGlanceModule.swift")

        // Compact labels belong to the module, next to the full titles, so the
        // view never becomes a second place that names the tools.
        XCTAssertTrue(moduleSource.contains(#"return "CX""#))
        XCTAssertTrue(moduleSource.contains(#"return "CL""#))
        XCTAssertTrue(moduleSource.contains(#"return "AG""#))
        XCTAssertTrue(viewSource.contains("item.module.compactTitle ?? item.title"))
        XCTAssertFalse(viewSource.contains(#"return "CX""#))
        XCTAssertTrue(viewSource.contains("item.tint.color.opacity(0.14)"))
        XCTAssertTrue(tintSource.contains("TokenUsageAITool.codex.dashboardTint"))
        XCTAssertTrue(tintSource.contains("TokenUsageAITool.claude.dashboardTint"))
        XCTAssertTrue(tintSource.contains("TokenUsageAITool.antigravity.dashboardTint"))
    }

    func testAllAndTickerUseOneBoundedPresentationOnlyRollingSchedule() throws {
        let viewSource = try source(at: "Sources/Spill/Glance/SpillGlanceView.swift")
        let storeSource = try source(at: "Sources/Spill/Glance/SpillGlanceStore.swift")
        let itemSource = try source(at: "Sources/Spill/Glance/SpillGlanceItem.swift")

        XCTAssertEqual(
            viewSource.occurrenceCount(of: "TimelineView("),
            1,
            "Only the root Glance surface should own the rotating schedule."
        )
        XCTAssertTrue(
            viewSource.contains("store.presentation.rotationSchedule"),
            "The root schedule must come from the presentation, not from the view."
        )
        XCTAssertTrue(itemSource.contains("static let rotationInterval: TimeInterval = 5"))
        XCTAssertTrue(viewSource.contains("store.presentation.visibleItems(at: date)"))
        XCTAssertTrue(
            viewSource.contains(".accessibilityLabel(accessibilityLabel(at: date))")
                && viewSource.contains("store.presentation.items"),
            "VoiceOver must read every module, not only the slot on screen."
        )
        XCTAssertTrue(viewSource.contains("$0.displayValue(at: date)"))
        XCTAssertTrue(storeSource.contains("$glanceWorkRotationEnabled"))
        XCTAssertTrue(storeSource.contains("nextRotationIdentity != rotationIdentity"))
        XCTAssertTrue(storeSource.contains("rotationEpoch = now()"))
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
            controllerSource.contains("presentedLayoutSignature != layoutSignature"),
            """
            Token or rotation-value changes must not reapply the saved window frame.
            Only an ordered module or display-style change should resize or reposition the panel.
            """
        )
    }

    func testFullScreenPreferenceReassignsTheVisiblePanelImmediately() throws {
        let controllerSource = try source(
            at: "Sources/Spill/Glance/SpillGlancePanelController.swift"
        )

        XCTAssertTrue(controllerSource.contains("presentedShowInFullScreen"))
        XCTAssertTrue(
            controllerSource.contains("if panel.isVisible")
                && controllerSource.contains("panel.orderOut(nil)")
        )
        XCTAssertTrue(
            controllerSource.contains("showInFullScreen: presentation.showInFullScreen")
        )
        XCTAssertTrue(
            controllerSource.contains("if !panel.isVisible")
                && controllerSource.contains("panel.orderFrontRegardless()")
        )
    }

    func testDisplayStylesUseOneHorizontalSurfaceWithFixedTypography() throws {
        let viewSource = try source(at: "Sources/Spill/Glance/SpillGlanceView.swift")
        let storeSource = try source(at: "Sources/Spill/Glance/SpillGlanceStore.swift")
        let preferencesSource = try source(
            at: "Sources/Spill/Preferences/Sections/SpillGlancePreferencesSection.swift"
        )

        XCTAssertTrue(viewSource.contains("HStack(spacing: SpillGlanceLayout.itemSpacing)"))
        XCTAssertFalse(viewSource.contains("VStack(spacing: SpillGlanceLayout.itemSpacing)"))
        XCTAssertFalse(viewSource.contains("minimumScaleFactor"))
        XCTAssertTrue(viewSource.contains(".fixedSize(horizontal: true, vertical: false)"))
        XCTAssertTrue(viewSource.contains("case .all:"))
        XCTAssertTrue(viewSource.contains("case .ticker:"))
        XCTAssertTrue(viewSource.contains("SpillGlanceLayout.tickerItemWidth"))
        // The ticker keeps one stable module view whose texts crossfade; view
        // identity swaps with move transitions re-laid text out every rotation.
        XCTAssertFalse(viewSource.contains(".move(edge:"))
        XCTAssertFalse(viewSource.contains(".id(item.renderID)"))
        XCTAssertTrue(viewSource.contains(".contentTransition(.opacity)"))
        XCTAssertTrue(
            viewSource.contains("labelStyle == .full ? .opacity : .interpolate"),
            "Ticker value swaps crossfade; compact digit updates keep interpolating."
        )
        XCTAssertTrue(
            viewSource.contains("store.isRotationPaused"),
            "An occluded panel must not keep a rotation schedule ticking."
        )
        XCTAssertTrue(storeSource.contains("$glanceDisplayStyle"))
        XCTAssertTrue(storeSource.contains("$glanceShowInFullScreen"))
        XCTAssertTrue(preferencesSource.contains("$settings.glanceDisplayStyle"))
        XCTAssertTrue(preferencesSource.contains("$settings.glanceShowInFullScreen"))
        XCTAssertTrue(preferencesSource.contains("$settings.glanceReactiveRotationEnabled"))
        XCTAssertTrue(
            preferencesSource.contains("VStack(alignment: .leading, spacing: 9)"),
            "Detail copy must stay leading-aligned with the rest of the section."
        )
    }

    func testReactiveRotationIsChangeDrivenThrottledAndPresentationOwned() throws {
        let viewSource = try source(at: "Sources/Spill/Glance/SpillGlanceView.swift")
        let storeSource = try source(at: "Sources/Spill/Glance/SpillGlanceStore.swift")
        let queueSource = try source(at: "Sources/Spill/Glance/SpillGlanceChangeQueue.swift")
        let detectionSource = try source(
            at: "Sources/Spill/Glance/SpillGlanceChangeDetection.swift"
        )
        let scheduleSource = try source(
            at: "Sources/Spill/Glance/SpillGlanceRotationTimelineSchedule.swift"
        )

        XCTAssertTrue(storeSource.contains("$glanceReactiveRotationEnabled"))
        XCTAssertTrue(
            detectionSource.contains("queue.enqueue(")
                && detectionSource.contains("pendingChanges("),
            "Reactive rotation must be fed by diffed snapshots, not by a periodic tick."
        )
        XCTAssertTrue(
            detectionSource.contains("didReconfigure"),
            "Reconfiguring the surface must not be mistaken for a usage change."
        )
        XCTAssertFalse(
            detectionSource.contains("import Combine")
                || detectionSource.contains("import AppKit")
                || detectionSource.contains("import SwiftUI"),
            "Change detection must stay pure snapshot-diff rules."
        )
        XCTAssertTrue(
            queueSource.contains("entries.firstIndex(where: { $0.module == change.module })"),
            "A module that keeps changing must coalesce into its pending slot."
        )
        XCTAssertTrue(queueSource.contains("entries.removeAll { $0.end <= date }"))
        XCTAssertTrue(scheduleSource.contains("case let .explicit(dates)"))
        XCTAssertTrue(scheduleSource.contains("case let .periodic(from, interval)"))
        XCTAssertFalse(scheduleSource.contains("Timer("))
        XCTAssertFalse(viewSource.contains("scheduledTimer"))
    }

    func testPlacementUsesStableDisplayIdentityAndVisibleFrameSemantics() throws {
        let controllerSource = try source(
            at: "Sources/Spill/Glance/SpillGlancePanelController.swift"
        )
        let placementSource = try source(
            at: "Sources/Spill/Glance/SpillGlancePlacement.swift"
        )
        let screenProviderSource = try source(
            at: "Sources/Spill/Glance/SpillGlanceScreenProvider.swift"
        )
        let frameStoreSource = try source(
            at: "Sources/Spill/Glance/SpillGlanceFrameStore.swift"
        )

        XCTAssertTrue(controllerSource.contains("screenProvider.descriptors()"))
        XCTAssertTrue(screenProviderSource.contains("CGDisplayCreateUUIDFromDisplayID"))
        XCTAssertTrue(screenProviderSource.contains("visibleFrame: screen.visibleFrame"))
        XCTAssertTrue(placementSource.contains("case leading"))
        XCTAssertTrue(placementSource.contains("case trailing"))
        XCTAssertTrue(placementSource.contains("case bottom"))
        XCTAssertTrue(placementSource.contains("case top"))
        XCTAssertTrue(placementSource.contains("normalizedX"))
        XCTAssertTrue(placementSource.contains("normalizedY"))
        XCTAssertTrue(frameStoreSource.contains("spillGlancePlacementV2"))
        XCTAssertTrue(frameStoreSource.contains("legacyFrame"))
    }

    func testPanelPlatformObjectsKeepOneTopLevelOwnerPerSourceFile() throws {
        let panelSource = try source(at: "Sources/Spill/Glance/SpillGlancePanel.swift")
        let hostingSource = try source(
            at: "Sources/Spill/Glance/SpillGlanceHostingView.swift"
        )
        let storeSource = try source(at: "Sources/Spill/Glance/SpillGlanceStore.swift")
        let rotationIdentitySource = try source(
            at: "Sources/Spill/Glance/SpillGlanceRotationIdentity.swift"
        )
        let screenProviderSource = try source(
            at: "Sources/Spill/Glance/SpillGlanceScreenProvider.swift"
        )

        XCTAssertTrue(panelSource.contains("final class SpillGlancePanel: NSPanel"))
        XCTAssertFalse(panelSource.contains("SpillGlanceHostingView"))
        XCTAssertTrue(hostingSource.contains("final class SpillGlanceHostingView"))
        XCTAssertFalse(hostingSource.contains("final class SpillGlancePanel: NSPanel"))
        XCTAssertTrue(storeSource.contains("final class SpillGlanceStore: ObservableObject"))
        XCTAssertFalse(storeSource.contains("struct SpillGlanceRotationIdentity"))
        XCTAssertTrue(
            rotationIdentitySource.contains("struct SpillGlanceRotationIdentity: Equatable")
        )
        XCTAssertFalse(rotationIdentitySource.contains("final class SpillGlanceStore"))
        XCTAssertTrue(screenProviderSource.contains("struct SpillGlanceScreenProvider"))
        XCTAssertFalse(screenProviderSource.contains("final class SpillGlancePanelController"))
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
