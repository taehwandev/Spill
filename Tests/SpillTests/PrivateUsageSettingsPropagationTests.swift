import AppKit
import Combine
import XCTest
@testable import Spill

@MainActor
final class PrivateUsageSettingsPropagationTests: XCTestCase {
    func testConsentChangesReachAnExistingHelperAfterPersistence() async throws {
        let fixture = makeFixture()
        var received: [Bool] = []
        let subscription = TokenMeteringDashboardProcess.observePrivateUsageUploadSettings(
            settings: fixture.main,
            postChange: {
                let persisted = fixture.writerDefaults.value(
                    for: .privateUsageUploadEnabled(for: fixture.main.privateUsageUploadEnvironment)
                )
                XCTAssertEqual(persisted, fixture.main.privateUsageUploadEnabled)
                fixture.delegate.settingsDidChangeFromMainApp(self.settingsNotification())
                received.append(fixture.helper.privateUsageUploadEnabled)
            }
        )
        defer { subscription.cancel() }

        fixture.main.privateUsageUploadEnabled = true
        XCTAssertFalse(fixture.helper.privateUsageUploadEnabled)
        try await waitUntil { received.count == 1 }
        XCTAssertTrue(fixture.helper.privateUsageUploadEnabled)

        // Disconnect and the consent toggle both persist false through this same setting.
        fixture.main.privateUsageUploadEnabled = false
        try await waitUntil { received.count == 2 }
        XCTAssertFalse(fixture.helper.privateUsageUploadEnabled)
        XCTAssertEqual(received, [true, false])
    }

    func testEnvironmentChangesReloadTheirOwnConsentWithoutCopyingIt() async throws {
        let fixture = makeFixture(initialConsent: true)
        let subscription = TokenMeteringDashboardProcess.observePrivateUsageUploadSettings(
            settings: fixture.main,
            postChange: {
                XCTAssertEqual(
                    fixture.writerDefaults.value(for: .privateUsageUploadEnvironment),
                    fixture.main.privateUsageUploadEnvironment
                )
                fixture.delegate.settingsDidChangeFromMainApp(self.settingsNotification())
                XCTAssertEqual(fixture.helper.privateUsageUploadEnvironment, fixture.main.privateUsageUploadEnvironment)
                XCTAssertEqual(fixture.helper.privateUsageUploadEnabled, fixture.main.privateUsageUploadEnabled)
            }
        )
        defer { subscription.cancel() }

        fixture.main.privateUsageUploadEnvironment = .development
        try await waitUntil {
            fixture.helper.privateUsageUploadEnvironment == .development
                && !fixture.helper.privateUsageUploadEnabled
        }
        XCTAssertTrue(fixture.writerDefaults.value(for: .privateUsageUploadEnabled(for: .production)))
        XCTAssertFalse(fixture.writerDefaults.value(for: .privateUsageUploadEnabled(for: .development)))

        fixture.main.privateUsageUploadEnvironment = .production
        try await waitUntil {
            fixture.helper.privateUsageUploadEnvironment == .production
                && fixture.helper.privateUsageUploadEnabled
        }
        XCTAssertFalse(fixture.writerDefaults.value(for: .privateUsageUploadEnabled(for: .development)))
    }

    func testFullSettingsNotificationReloadsEnvironmentAndConsent() {
        _ = NSApplication.shared
        let fixture = makeFixture()
        fixture.main.privateUsageUploadEnabled = true
        fixture.writerDefaults.synchronize()

        fixture.delegate.settingsDidChangeFromMainApp(settingsNotification(key: nil))
        XCTAssertTrue(fixture.helper.privateUsageUploadEnabled)

        fixture.main.privateUsageUploadEnvironment = .development
        fixture.writerDefaults.synchronize()
        fixture.delegate.settingsDidChangeFromMainApp(settingsNotification(key: nil))
        XCTAssertEqual(fixture.helper.privateUsageUploadEnvironment, .development)
        XCTAssertFalse(fixture.helper.privateUsageUploadEnabled)
        XCTAssertTrue(fixture.writerDefaults.value(for: .privateUsageUploadEnabled(for: .production)))
    }

    func testUnrelatedSettingsNotificationDoesNotReloadUploadConsent() {
        let fixture = makeFixture()
        fixture.main.privateUsageUploadEnabled = true
        fixture.writerDefaults.synchronize()

        fixture.delegate.settingsDidChangeFromMainApp(settingsNotification(key: "unrelated-setting"))
        XCTAssertFalse(fixture.helper.privateUsageUploadEnabled)

        fixture.delegate.settingsDidChangeFromMainApp(settingsNotification())
        XCTAssertTrue(fixture.helper.privateUsageUploadEnabled)
    }

    func testRepeatedReloadDoesNotRepublishUnchangedConsent() {
        let fixture = makeFixture()
        var publications = 0
        let subscription = fixture.helper.$privateUsageUploadEnabled.dropFirst().sink { _ in
            publications += 1
        }
        defer { subscription.cancel() }

        fixture.main.privateUsageUploadEnabled = true
        fixture.writerDefaults.synchronize()
        fixture.helper.reloadPrivateUsageUploadSettingsFromDefaults()
        fixture.helper.reloadPrivateUsageUploadSettingsFromDefaults()

        XCTAssertTrue(fixture.helper.privateUsageUploadEnabled)
        XCTAssertEqual(publications, 1)
    }

    private func settingsNotification(
        key: String? = TokenMeteringDashboardProcess.privateUsageUploadSettingsKey
    ) -> Notification {
        Notification(
            name: TokenMeteringDashboardProcess.settingsDidChangeNotification,
            userInfo: key.map { [TokenMeteringDashboardProcess.settingsKeyUserInfoKey: $0] }
        )
    }

    private func waitUntil(_ predicate: () -> Bool) async throws {
        for _ in 0..<100 {
            if predicate() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Persisted upload settings did not reach the existing helper")
    }

    private struct Fixture {
        let main: SpillSettings
        let helper: SpillSettings
        let delegate: TokenMeteringDashboardAppDelegate
        let writerDefaults: UserDefaults
    }

    private func makeFixture(initialConsent: Bool = false) -> Fixture {
        let suiteName = "PrivateUsageSettingsPropagationTests-\(UUID().uuidString)"
        let writerDefaults = UserDefaults(suiteName: suiteName)!
        let readerDefaults = UserDefaults(suiteName: suiteName)!
        writerDefaults.removePersistentDomain(forName: suiteName)
        writerDefaults.store(PrivateUsageUploadEnvironment.production, for: .privateUsageUploadEnvironment)
        writerDefaults.store(initialConsent, for: .privateUsageUploadEnabled(for: .production))
        writerDefaults.store(false, for: .privateUsageUploadEnabled(for: .development))
        writerDefaults.synchronize()
        let main = SpillSettings(defaults: writerDefaults)
        let helper = SpillSettings(defaults: readerDefaults)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let delegate = TokenMeteringDashboardAppDelegate(
            settings: helper,
            tokenUsageStore: TokenUsageStore(fileURL: directory.appendingPathComponent("events.json"))
        )
        addTeardownBlock {
            writerDefaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: directory)
        }
        return Fixture(main: main, helper: helper, delegate: delegate, writerDefaults: writerDefaults)
    }
}
