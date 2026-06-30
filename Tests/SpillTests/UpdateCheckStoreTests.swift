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

    func testCopyInstallCommandUsesStableReleaseDownloadWhenUpdateIsAvailable() async throws {
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
        XCTAssertEqual(
            store.installCommand,
            "curl -L -O https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.dmg && open Spill-macos.dmg"
        )
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

    func testOpenUpdateUsesInAppUpdaterWhenAvailable() async throws {
        let data = updateManifestData(latestVersion: "2026.20.2")
        var openedURL: URL?
        var checkedSource: String?
        let store = UpdateCheckStore(
            checker: UpdateChecker(
                currentVersion: "2026.20.1",
                currentMacOS: DottedVersion("14.5.0")!,
                dataLoader: { _ in data }
            ),
            openURL: { openedURL = $0 },
            copyText: { _ in },
            isInAppUpdaterAvailable: { true },
            runInAppUpdateCheck: { source in
                checkedSource = source
                return true
            },
            defaults: makeDefaults()
        )

        store.checkForUpdatesIfNeeded(source: "panel_open")
        try await waitForAvailableUpdate(in: store)
        store.openUpdate(source: "panel")

        XCTAssertEqual(checkedSource, "panel")
        XCTAssertNil(openedURL)
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

    func testDashboardRestoresCachedAvailableStateWithoutRerunningWithinInterval() async throws {
        let data = updateManifestData(latestVersion: "2026.20.2")
        let loadCounter = LockedCounter()
        let defaults = makeDefaults()
        let currentDate = Date(timeIntervalSince1970: 100)
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in
                loadCounter.increment()
                return data
            }
        )

        let firstStore = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in },
            defaults: defaults,
            now: { currentDate }
        )
        firstStore.checkForUpdatesIfNeeded(source: "panel_open")
        try await waitForAvailableUpdate(in: firstStore)

        let relaunchedStore = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in },
            defaults: defaults,
            now: { currentDate.addingTimeInterval(60) }
        )

        XCTAssertTrue(relaunchedStore.canOpenUpdate)
        XCTAssertTrue(relaunchedStore.showsDashboardUpdateStatus)

        relaunchedStore.checkForUpdatesIfNeeded(source: "panel_open")

        XCTAssertEqual(loadCounter.value, 1)
    }

    func testDashboardRestoresCachedUnsupportedStateWithoutRerunningWithinInterval() async throws {
        let data = updateManifestData(latestVersion: "2026.20.2", minimumMacOS: "15.0")
        let loadCounter = LockedCounter()
        let defaults = makeDefaults()
        let currentDate = Date(timeIntervalSince1970: 100)
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in
                loadCounter.increment()
                return data
            }
        )

        let firstStore = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in },
            defaults: defaults,
            now: { currentDate }
        )
        firstStore.checkForUpdatesIfNeeded(source: "panel_open")
        try await waitForUnsupportedUpdate(in: firstStore)

        let relaunchedStore = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in },
            defaults: defaults,
            now: { currentDate.addingTimeInterval(60) }
        )

        if case .unsupported(let update, let currentMacOS) = relaunchedStore.state {
            XCTAssertEqual(update.latestVersion, "2026.20.2")
            XCTAssertEqual(currentMacOS, "14.5.0")
        } else {
            XCTFail("Expected cached unsupported update state.")
        }
        XCTAssertTrue(relaunchedStore.showsDashboardUpdateStatus)

        relaunchedStore.checkForUpdatesIfNeeded(source: "panel_open")

        XCTAssertEqual(loadCounter.value, 1)
    }

    func testDashboardIgnoresCachedManifestOlderThanCurrentVersion() async throws {
        let data = updateManifestData(latestVersion: "2026.20.2")
        let defaults = makeDefaults()
        let currentDate = Date(timeIntervalSince1970: 100)
        let firstChecker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in data }
        )
        let firstStore = UpdateCheckStore(
            checker: firstChecker,
            openURL: { _ in },
            copyText: { _ in },
            defaults: defaults,
            now: { currentDate }
        )
        firstStore.checkForUpdatesIfNeeded(source: "panel_open")
        try await waitForAvailableUpdate(in: firstStore)

        let newerChecker = UpdateChecker(
            currentVersion: "2026.20.3",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in data }
        )
        let relaunchedStore = UpdateCheckStore(
            checker: newerChecker,
            openURL: { _ in },
            copyText: { _ in },
            defaults: defaults,
            now: { currentDate.addingTimeInterval(60) }
        )

        XCTAssertEqual(relaunchedStore.state, .idle(currentVersion: "2026.20.3"))
        XCTAssertFalse(relaunchedStore.showsDashboardUpdateStatus)
    }

    func testDashboardShowsUpToDateStatusAfterNoUpdate() async throws {
        let data = updateManifestData(latestVersion: "2026.20.1")
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in data }
        )
        let store = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in },
            defaults: makeDefaults()
        )

        store.checkForUpdatesIfNeeded(source: "panel_open")
        try await waitForUpToDateUpdate(in: store)

        XCTAssertFalse(store.showsDashboardUpdateStatus)
    }

    func testDashboardFailedStateCanRetryInsideCachedInterval() async throws {
        let data = updateManifestData(latestVersion: "2026.20.2")
        let loadCounter = LockedCounter()
        let shouldFail = LockedFlag(true)
        let defaults = makeDefaults()
        defaults.set(
            Date(timeIntervalSince1970: 100).timeIntervalSince1970,
            forKey: "dev.spill.update.lastDashboardCheckAt"
        )
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in
                loadCounter.increment()
                if shouldFail.isSet {
                    throw NSError(domain: "UpdateCheckStoreTests", code: 1)
                }
                return data
            }
        )
        let store = UpdateCheckStore(
            checker: checker,
            openURL: { _ in },
            copyText: { _ in },
            defaults: defaults,
            now: { Date(timeIntervalSince1970: 160) }
        )

        store.checkForUpdatesIfNeeded(source: "panel_open")
        try await waitForFailedUpdate(in: store)

        shouldFail.set(false)
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

    private func updateManifestData(latestVersion: String, minimumMacOS: String = "14.0") -> Data {
        """
        {
          "latestVersion": "\(latestVersion)",
          "build": "42",
          "minimumMacOS": "\(minimumMacOS)",
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

    private func waitForUnsupportedUpdate(in store: UpdateCheckStore) async throws {
        for _ in 0..<20 {
            if case .unsupported = store.state {
                return
            }

            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Expected update store to reach unsupported state.")
    }

    private func waitForUpToDateUpdate(in store: UpdateCheckStore) async throws {
        for _ in 0..<20 {
            if case .upToDate = store.state {
                return
            }

            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Expected update store to reach up-to-date state.")
    }

    private func waitForFailedUpdate(in store: UpdateCheckStore) async throws {
        for _ in 0..<20 {
            if case .failed = store.state {
                return
            }

            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Expected update store to reach failed state.")
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

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool

    init(_ value: Bool) {
        self.value = value
    }

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ value: Bool) {
        lock.lock()
        self.value = value
        lock.unlock()
    }
}
