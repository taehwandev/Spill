import XCTest
@testable import Spill

@MainActor
final class UpdateCheckStoreTests: XCTestCase {
    func testInitialStateIsIdleInsteadOfForcedAvailable() {
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in Data() }
        )
        let store = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in }
        )

        XCTAssertEqual(store.state, .idle(currentVersion: "2026.20.1"))
        XCTAssertFalse(store.canOpenUpdate)
    }

    func testCopyInstallCommandUsesPublicInstallScriptWhenUpdateIsAvailable() async throws {
        let data = """
        {
          "latestVersion": "2026.20.2",
          "build": "42",
          "minimumMacOS": "14.0",
          "downloadURL": "https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.dmg",
          "releaseNotesURL": "https://github.com/taehwandev/Spill/releases/latest",
          "publishedAt": "2026-05-17T00:00:00Z"
        }
        """.data(using: .utf8)!
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in data }
        )
        var copiedText: String?
        let store = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { copiedText = $0 }
        )

        store.checkForUpdates(source: "test")
        try await waitForAvailableUpdate(in: store)
        store.copyInstallCommand(source: "test")

        XCTAssertEqual(copiedText, UpdateCheckStore.defaultInstallCommand)
        XCTAssertEqual(store.installCommand, #"/bin/bash -c "$(curl -fsSL https://spill.thdev.app/install.sh)""#)
    }

    func testOpenUpdatePrefersInstallerPackageWhenAvailable() async throws {
        let data = """
        {
          "latestVersion": "2026.20.2",
          "build": "42",
          "minimumMacOS": "14.0",
          "downloadURL": "https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.dmg",
          "packageURL": "https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.pkg",
          "releaseNotesURL": "https://github.com/taehwandev/Spill/releases/latest",
          "publishedAt": "2026-05-17T00:00:00Z"
        }
        """.data(using: .utf8)!
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in data }
        )
        var openedURL: URL?
        let store = UpdateCheckStore(
            checker: checker,
            openURL: { openedURL = $0 },
            copyText: { _ in }
        )

        store.checkForUpdates(source: "test")
        try await waitForAvailableUpdate(in: store)
        store.openUpdate(source: "test")

        XCTAssertEqual(openedURL?.absoluteString, "https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.pkg")
    }

    func testCheckForUpdatesUsesInAppUpdaterWhenAvailable() {
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in
                XCTFail("Manifest checker should not run when the in-app updater handles the check.")
                return Data()
            }
        )
        var checkedSource: String?
        let store = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in },
            isInAppUpdaterAvailable: { true },
            runInAppUpdateCheck: { source in
                checkedSource = source
                return true
            }
        )

        store.checkForUpdates(source: "test")

        XCTAssertEqual(checkedSource, "test")
        XCTAssertEqual(store.state, .idle(currentVersion: "2026.20.1"))
    }

    func testCheckForUpdatesFallsBackToManifestWhenInAppUpdaterIsUnavailable() async throws {
        let data = """
        {
          "latestVersion": "2026.20.2",
          "build": "42",
          "minimumMacOS": "14.0",
          "downloadURL": "https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.dmg",
          "releaseNotesURL": "https://github.com/taehwandev/Spill/releases/latest",
          "publishedAt": "2026-05-17T00:00:00Z"
        }
        """.data(using: .utf8)!
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in data }
        )
        let store = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in },
            isInAppUpdaterAvailable: { false },
            runInAppUpdateCheck: { _ in false }
        )

        store.checkForUpdates(source: "test")
        try await waitForAvailableUpdate(in: store)

        XCTAssertEqual(store.availableUpdate?.latestVersion, "2026.20.2")
    }

    func testDashboardCheckRunsManifestOncePerInterval() async throws {
        let data = updateManifestData(latestVersion: "2026.20.2")
        let loadCounter = LockedCounter()
        let defaults = makeDefaults()
        var currentDate = Date(timeIntervalSince1970: 100)
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in
                loadCounter.increment()
                return data
            }
        )
        let store = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in },
            defaults: defaults,
            now: { currentDate }
        )

        store.checkForUpdatesIfNeeded(source: "panel_open")
        try await waitForAvailableUpdate(in: store)
        store.checkForUpdatesIfNeeded(source: "panel_open")

        XCTAssertEqual(loadCounter.value, 1)

        currentDate = currentDate.addingTimeInterval((24 * 60 * 60) + 1)
        store.checkForUpdatesIfNeeded(source: "panel_open")
        try await waitForAvailableUpdate(in: store)

        XCTAssertEqual(loadCounter.value, 2)
    }

    func testDashboardCheckDoesNotUseSparkleForegroundUpdater() async throws {
        let data = updateManifestData(latestVersion: "2026.20.2")
        let loadCounter = LockedCounter()
        let sparkleCounter = LockedCounter()
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in
                loadCounter.increment()
                return data
            }
        )
        let store = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in },
            isInAppUpdaterAvailable: { true },
            runInAppUpdateCheck: { _ in
                sparkleCounter.increment()
                return true
            },
            defaults: makeDefaults()
        )

        store.checkForUpdatesIfNeeded(source: "panel_open")
        try await waitForAvailableUpdate(in: store)

        XCTAssertEqual(loadCounter.value, 1)
        XCTAssertEqual(sparkleCounter.value, 0)
        XCTAssertEqual(store.availableUpdate?.latestVersion, "2026.20.2")
    }

    func testManualCheckBypassesDashboardCache() async throws {
        let data = updateManifestData(latestVersion: "2026.20.2")
        let loadCounter = LockedCounter()
        let defaults = makeDefaults()
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in
                loadCounter.increment()
                return data
            }
        )
        let store = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in },
            defaults: defaults
        )

        store.checkForUpdatesIfNeeded(source: "panel_open")
        try await waitForAvailableUpdate(in: store)
        store.checkForUpdates(source: "preferences")
        try await waitForAvailableUpdate(in: store)

        XCTAssertEqual(loadCounter.value, 2)
    }

    func testCopyInstallCommandDoesNothingBeforeAvailableUpdate() {
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in Data() }
        )
        var copiedText: String?
        let store = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { copiedText = $0 }
        )

        store.copyInstallCommand(source: "test")

        XCTAssertNil(copiedText)
    }

    private func updateManifestData(latestVersion: String) -> Data {
        """
        {
          "latestVersion": "\(latestVersion)",
          "build": "42",
          "minimumMacOS": "14.0",
          "downloadURL": "https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.dmg",
          "releaseNotesURL": "https://github.com/taehwandev/Spill/releases/latest",
          "publishedAt": "2026-05-17T00:00:00Z"
        }
        """.data(using: .utf8)!
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "dev.spill.UpdateCheckStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func waitForAvailableUpdate(in store: UpdateCheckStore) async throws {
        for _ in 0..<20 {
            if store.canOpenUpdate {
                return
            }

            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Expected update store to reach available state.")
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
