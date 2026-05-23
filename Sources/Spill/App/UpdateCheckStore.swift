import AppKit
import Foundation

@MainActor
final class UpdateCheckStore: ObservableObject {
    static let defaultInstallCommand = #"/bin/bash -c "$(curl -fsSL https://spill.thdev.app/install.sh)""#

    @Published private(set) var state: UpdateCheckState

    private let checker: UpdateChecker
    private let openURL: (URL) -> Void
    private let copyText: @MainActor (String) -> Void
    private let isInAppUpdaterAvailable: @MainActor () -> Bool
    private let runInAppUpdateCheck: @MainActor (String) -> Bool
    private var checkTask: Task<Void, Never>?

    init(
        checker: UpdateChecker = UpdateChecker(),
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
        copyText: @escaping @MainActor (String) -> Void = UpdateCheckStore.copyToPasteboard(_:),
        isInAppUpdaterAvailable: @escaping @MainActor () -> Bool = { false },
        runInAppUpdateCheck: @escaping @MainActor (String) -> Bool = { _ in false }
    ) {
        self.checker = checker
        self.openURL = openURL
        self.copyText = copyText
        self.isInAppUpdaterAvailable = isInAppUpdaterAvailable
        self.runInAppUpdateCheck = runInAppUpdateCheck
        state = .idle(currentVersion: checker.currentVersion)
    }

    deinit {
        checkTask?.cancel()
    }

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

        if runInAppUpdateCheck(source) {
            SpillTelemetry.shared.track(
                "update_check_started",
                props: [
                    "source": source,
                    "engine": "sparkle"
                ]
            )
            return
        }

        SpillTelemetry.shared.track(
            "update_check_started",
            props: [
                "source": source,
                "engine": "manifest"
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

    func openUpdate(source: String = "preferences") {
        guard case .available(let update) = state else {
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
