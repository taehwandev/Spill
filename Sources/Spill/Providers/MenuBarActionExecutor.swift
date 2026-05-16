import AppKit

@MainActor
struct MenuBarActionExecutor {
    let scanner: AXMenuBarItemScanner

    func perform(_ action: SpillAction) -> SpillActionResult {
        guard action.state.isEnabled else {
            return .failed(message: action.state.disabledReason ?? "Action disabled")
        }

        switch action.kind {
        case .menuBarItem:
            guard let snapshotID = MenuBarActionAdapter.sourceSnapshotID(for: action) else {
                return .failed(message: "Menu unavailable")
            }

            return scanner.pressItem(withID: snapshotID) ? .success : .failed(message: "Menu unavailable")
        case let .app(bundleIdentifier):
            return activateApp(bundleIdentifier: bundleIdentifier) ? .success : .failed(message: "Action unavailable")
        case .window, .command:
            return .unsupported
        }
    }

    private func activateApp(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else {
            return false
        }

        if let runningApp = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first
        {
            return runningApp.activate(options: [])
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        return true
    }
}
