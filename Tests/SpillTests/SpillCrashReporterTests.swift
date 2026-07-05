import AppKit
import XCTest
@testable import Spill

final class SpillCrashReporterTests: XCTestCase {
    func testLifecycleMarkerDoesNotReportWhenRecordedProcessIsStillRunning() throws {
        let currentProcessID = Darwin.getpid()
        let marker = SpillCrashReporter.LifecycleMarker(
            processRole: "main_app",
            launchID: "current-launch",
            processID: currentProcessID + 1,
            bundleIdentifier: nil,
            markerURL: temporaryMarkerURL()
        )
        let previousState = SpillCrashReporter.LifecycleState.running(
            processRole: "main_app",
            launchID: "previous-launch",
            processID: currentProcessID,
            bundleIdentifier: nil
        )

        XCTAssertFalse(marker.shouldReportPreviousUncleanExit(previousState))
    }

    func testLifecycleMarkerReportsLegacyRunningMarkerWithoutProcessMetadata() throws {
        let markerURL = temporaryMarkerURL()
        let payload = """
        {
          "state": "running",
          "processRole": "main_app",
          "updatedAt": "2026-07-01T00:00:00Z"
        }
        """
        try payload.write(to: markerURL, atomically: true, encoding: .utf8)
        let marker = SpillCrashReporter.LifecycleMarker(
            processRole: "main_app",
            launchID: "current-launch",
            processID: Darwin.getpid(),
            bundleIdentifier: Bundle.main.bundleIdentifier,
            markerURL: markerURL
        )

        let previousState = try XCTUnwrap(marker.read())

        XCTAssertNil(previousState.launchID)
        XCTAssertNil(previousState.processID)
        XCTAssertTrue(marker.shouldReportPreviousUncleanExit(previousState))
    }

    func testCleanShutdownDoesNotOverwriteNewerRunningLaunchMarker() throws {
        let markerURL = temporaryMarkerURL()
        let oldMarker = SpillCrashReporter.LifecycleMarker(
            processRole: "main_app",
            launchID: "old-launch",
            processID: 100,
            bundleIdentifier: "app.spill",
            markerURL: markerURL
        )
        let newMarker = SpillCrashReporter.LifecycleMarker(
            processRole: "main_app",
            launchID: "new-launch",
            processID: 101,
            bundleIdentifier: "app.spill",
            markerURL: markerURL
        )

        oldMarker.markRunning()
        newMarker.markRunning()
        oldMarker.markCleanShutdownIfCurrentRun()

        var state = try XCTUnwrap(newMarker.read())
        XCTAssertEqual(state.state, "running")
        XCTAssertEqual(state.launchID, "new-launch")

        newMarker.markCleanShutdownIfCurrentRun()
        state = try XCTUnwrap(newMarker.read())
        XCTAssertEqual(state.state, "clean_shutdown")
        XCTAssertEqual(state.launchID, "new-launch")
    }

    private func temporaryMarkerURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCrashReporterTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
            .appendingPathComponent("lifecycle-main_app.json")
    }
}
