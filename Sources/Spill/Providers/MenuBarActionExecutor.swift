import AppKit

@MainActor
struct MenuBarActionExecutor {
    let scanner: AXMenuBarItemScanner

    func perform(_ action: SpillAction) -> SpillActionResult {
        guard action.state.isEnabled else {
            return .failed(message: action.state.disabledReason ?? "Action disabled")
        }

        if let snapshotID = MenuBarActionAdapter.sourceSnapshotID(for: action),
           scanner.pressItem(withID: snapshotID)
        {
            return .success
        }

        if activateApp(bundleIdentifier: MenuBarActionAdapter.sourceBundleIdentifier(for: action)) {
            return .success
        }

        return .failed(message: "Action unavailable")
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
