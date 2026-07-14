import AppKit
import Foundation

@MainActor
final class UpdateCheckStore: ObservableObject {
    static let defaultInstallCommand = "curl -L -O https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.dmg && open Spill-macos.dmg"

    @Published private(set) var state: UpdateCheckState

    private static let automaticDashboardCheckKey = "dev.spill.update.lastDashboardCheckAt"
    private static let dashboardManifestCacheKey = "dev.spill.update.lastDashboardManifest"
    private static let automaticDashboardCheckInterval: TimeInterval = 24 * 60 * 60

    private let checker: UpdateChecker
    private let openURL: (URL) -> Void
    private let copyText: @MainActor (String) -> Void
    private let isInAppUpdaterAvailable: @MainActor () -> Bool
    private let runInAppUpdateCheck: @MainActor (String) -> Bool
    private let defaults: UserDefaults
    private let now: () -> Date
    private let automaticDashboardCheckInterval: TimeInterval
    private var checkTask: Task<Void, Never>?

    init(
        checker: UpdateChecker = UpdateChecker(),
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
        copyText: @escaping @MainActor (String) -> Void = UpdateCheckStore.copyToPasteboard(_:),
        isInAppUpdaterAvailable: @escaping @MainActor () -> Bool = { false },
        runInAppUpdateCheck: @escaping @MainActor (String) -> Bool = { _ in false },
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        automaticDashboardCheckInterval: TimeInterval = UpdateCheckStore.automaticDashboardCheckInterval
    ) {
        self.checker = checker
        self.openURL = openURL
        self.copyText = copyText
        self.isInAppUpdaterAvailable = isInAppUpdaterAvailable
        self.runInAppUpdateCheck = runInAppUpdateCheck
        self.defaults = defaults
        self.now = now
        self.automaticDashboardCheckInterval = automaticDashboardCheckInterval
        state = Self.cachedDashboardState(
            defaults: defaults,
            checker: checker,
            now: now(),
            automaticDashboardCheckInterval: automaticDashboardCheckInterval
        ) ?? .idle(currentVersion: checker.currentVersion)
    }

    deinit {
        checkTask?.cancel()
    }
}

extension UpdateCheckStore {
    var currentVersion: String {
        state.currentVersion
    }

    var isChecking: Bool {
        if case .checking = state {
            return true
        }
        return false
    }

    var availableUpdate: AvailableUpdate? {
        switch state {
        case .available(let update), .unsupported(let update, _):
            return update
        case .idle, .checking, .upToDate, .failed:
            return nil
        }
    }

    var canOpenUpdate: Bool {
        if case .available = state {
            return true
        }
        return false
    }

    var showsDashboardUpdateStatus: Bool {
        switch state {
        case .available, .unsupported:
            return true
        case .idle, .checking, .upToDate, .failed:
            return false
        }
    }

    var installCommand: String {
        Self.defaultInstallCommand
    }

    var usesInAppUpdater: Bool {
        isInAppUpdaterAvailable()
    }

    func checkForUpdates(source: String = "preferences") {
        guard !isChecking else {
            return
        }

        if startInAppUpdateCheck(source: source) {
            return
        }

        checkManifestForUpdates(source: source, engine: "manifest")
    }

    func checkForUpdatesIfNeeded(source: String = "dashboard") {
        guard !isChecking else {
            return
        }

        let currentDate = now()
        if hasKnownDashboardUpdateResult,
           let lastCheckAt = lastDashboardCheckAt,
           currentDate.timeIntervalSince(lastCheckAt) < automaticDashboardCheckInterval {
            SpillTelemetry.shared.track(
                "update_check_skipped",
                props: [
                    "source": source,
                    "reason": "dashboard_cache"
                ]
            )
            return
        }

        checkManifestForUpdates(
            source: source,
            engine: "manifest_dashboard",
            dashboardCheckDate: currentDate
        )
    }
}

private extension UpdateCheckStore {
    private var hasKnownDashboardUpdateResult: Bool {
        switch state {
        case .upToDate, .available, .unsupported:
            return true
        case .idle, .checking, .failed:
            return false
        }
    }

    private func checkManifestForUpdates(
        source: String,
        engine: String,
        dashboardCheckDate: Date? = nil
    ) {
        SpillTelemetry.shared.track(
            "update_check_started",
            props: [
                "source": source,
                "engine": engine
            ]
        )
        checkTask?.cancel()
        state = .checking(currentVersion: checker.currentVersion)
        let checker = checker

        checkTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                let outcome = try await checker.check()
                state = UpdateCheckState(outcome: outcome)
                if let dashboardCheckDate {
                    storeDashboardResult(outcome, checkedAt: dashboardCheckDate)
                }
                SpillTelemetry.shared.track(
                    "update_check_finished",
                    props: [
                        "source": source,
                        "result": telemetryResult(for: state)
                    ]
                )
            } catch is CancellationError {
                state = .idle(currentVersion: checker.currentVersion)
            } catch {
                state = .failed(
                    currentVersion: checker.currentVersion,
                    message: error.localizedDescription
                )
                SpillTelemetry.shared.track(
                    "update_check_finished",
                    props: [
                        "source": source,
                        "result": "failed"
                    ]
                )
            }
        }
    }
}

private extension UpdateCheckStore {
    private static func cachedDashboardState(
        defaults: UserDefaults,
        checker: UpdateChecker,
        now: Date,
        automaticDashboardCheckInterval: TimeInterval
    ) -> UpdateCheckState? {
        guard let timestamp = defaults.object(forKey: automaticDashboardCheckKey) as? Double,
              timestamp > 0,
              now.timeIntervalSince(Date(timeIntervalSince1970: timestamp)) < automaticDashboardCheckInterval,
              let data = defaults.data(forKey: dashboardManifestCacheKey),
              let manifest = try? JSONDecoder().decode(UpdateManifest.self, from: data),
              let cachedLatestVersion = DottedVersion(manifest.latestVersion),
              let currentVersion = DottedVersion(checker.currentVersion),
              cachedLatestVersion >= currentVersion,
              let outcome = try? checker.outcome(for: manifest)
        else {
            return nil
        }

        return UpdateCheckState(outcome: outcome)
    }

    private func storeDashboardResult(_ outcome: UpdateCheckOutcome, checkedAt: Date) {
        let manifest = dashboardManifest(for: outcome)

        guard let data = try? JSONEncoder().encode(manifest) else {
            defaults.removeObject(forKey: Self.dashboardManifestCacheKey)
            lastDashboardCheckAt = nil
            return
        }

        defaults.set(data, forKey: Self.dashboardManifestCacheKey)
        lastDashboardCheckAt = checkedAt
    }

    private func dashboardManifest(for outcome: UpdateCheckOutcome) -> UpdateManifest {
        switch outcome {
        case .upToDate(_, let manifest):
            return manifest
        case .available(let update), .unsupported(let update, _):
            return UpdateManifest(
                latestVersion: update.latestVersion,
                build: update.build,
                minimumMacOS: update.minimumMacOS,
                downloadURL: update.downloadURL,
                packageURL: update.packageURL,
                releaseNotesURL: update.releaseNotesURL,
                publishedAt: update.publishedAt
            )
        }
    }

    private var lastDashboardCheckAt: Date? {
        get {
            guard let timestamp = defaults.object(forKey: Self.automaticDashboardCheckKey) as? Double,
                  timestamp > 0 else {
                return nil
            }

            return Date(timeIntervalSince1970: timestamp)
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: Self.automaticDashboardCheckKey)
            } else {
                defaults.removeObject(forKey: Self.automaticDashboardCheckKey)
            }
        }
    }
}

extension UpdateCheckStore {
    func openUpdate(source: String = "preferences") {
        guard case .available(let update) = state else {
            return
        }

        if startInAppUpdateCheck(source: source, eventName: "update_download_opened") {
            return
        }

        SpillTelemetry.shared.track("update_download_opened", props: [
            "source": source,
            "artifact": update.usesInstallerPackage ? "pkg" : "dmg"
        ])
        openURL(update.preferredDownloadURL)
    }

    func copyInstallCommand(source: String = "preferences") {
        guard canOpenUpdate else {
            return
        }

        SpillTelemetry.shared.track("update_install_command_copied", props: ["source": source])
        copyText(installCommand)
    }

    func openReleaseNotes(source: String = "preferences") {
        guard let url = availableUpdate?.releaseNotesURL else {
            return
        }

        SpillTelemetry.shared.track("release_notes_opened", props: ["source": source])
        openURL(url)
    }

    private func telemetryResult(for state: UpdateCheckState) -> String {
        switch state {
        case .upToDate:
            return "up_to_date"
        case .available:
            return "available"
        case .unsupported:
            return "unsupported"
        case .failed:
            return "failed"
        case .idle, .checking:
            return "unknown"
        }
    }

    private func startInAppUpdateCheck(
        source: String,
        eventName: String = "update_check_started"
    ) -> Bool {
        guard isInAppUpdaterAvailable(), runInAppUpdateCheck(source) else {
            return false
        }

        SpillTelemetry.shared.track(
            eventName,
            props: [
                "source": source,
                "engine": "sparkle"
            ]
        )
        return true
    }

    private static func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

enum UpdateCheckState: Equatable {
    case idle(currentVersion: String)
    case checking(currentVersion: String)
    case upToDate(currentVersion: String, latestVersion: String)
    case available(AvailableUpdate)
    case unsupported(AvailableUpdate, currentMacOS: String)
    case failed(currentVersion: String, message: String)

    init(outcome: UpdateCheckOutcome) {
        switch outcome {
        case .upToDate(let currentVersion, let manifest):
            self = .upToDate(currentVersion: currentVersion, latestVersion: manifest.latestVersion)
        case .available(let update):
            self = .available(update)
        case .unsupported(let update, let currentMacOS):
            self = .unsupported(update, currentMacOS: currentMacOS)
        }
    }

    var currentVersion: String {
        switch self {
        case .idle(let currentVersion),
             .checking(let currentVersion),
             .upToDate(let currentVersion, _),
             .failed(let currentVersion, _):
            return currentVersion
        case .available(let update), .unsupported(let update, _):
            return update.currentVersion
        }
    }
}
