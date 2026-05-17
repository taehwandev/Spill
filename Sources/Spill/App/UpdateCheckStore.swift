import AppKit
import Foundation

@MainActor
final class UpdateCheckStore: ObservableObject {
    @Published private(set) var state: UpdateCheckState

    private let checker: UpdateChecker
    private let openURL: (URL) -> Void
    private var checkTask: Task<Void, Never>?

    init(
        checker: UpdateChecker = UpdateChecker(),
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.checker = checker
        self.openURL = openURL
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

    func checkForUpdates() {
        guard !isChecking else {
            return
        }

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
            } catch is CancellationError {
                state = .idle(currentVersion: checker.currentVersion)
            } catch {
                state = .failed(
                    currentVersion: checker.currentVersion,
                    message: error.localizedDescription
                )
            }
        }
    }

    func openUpdate() {
        guard case .available(let update) = state else {
            return
        }

        openURL(update.downloadURL)
    }

    func openReleaseNotes() {
        guard let url = availableUpdate?.releaseNotesURL else {
            return
        }

        openURL(url)
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
