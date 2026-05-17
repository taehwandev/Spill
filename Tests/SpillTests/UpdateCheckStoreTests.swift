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
        XCTAssertEqual(store.installCommand, #"/bin/bash -c "$(curl -fsSL https://thdev.app/Spill/install.sh)""#)
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
