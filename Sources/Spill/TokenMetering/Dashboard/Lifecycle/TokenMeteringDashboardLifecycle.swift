import AppKit
import Foundation

@MainActor
final class TokenMeteringDashboardLifecycle: NSObject {
    static let shared = TokenMeteringDashboardLifecycle()
    static let mainAppWillTerminateNotification = Notification.Name("app.spill.main-app-will-terminate")

    private var mainBundleIdentifier: String?
    private var observesMainApplicationTermination = false
    private var observesDashboardTerminationSignal = false
    private var observesDashboardMainApplicationTermination = false

    func observeMainApplicationTermination(mainBundleIdentifier: String?) {
        guard !observesMainApplicationTermination else {
            return
        }

        self.mainBundleIdentifier = mainBundleIdentifier
        observesMainApplicationTermination = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainApplicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    func observeDashboardMainApplicationTermination(mainBundleIdentifier: String?) {
        observeDashboardTerminationSignal()
        guard !observesDashboardMainApplicationTermination,
              let mainBundleIdentifier,
              !mainBundleIdentifier.isEmpty
        else {
            return
        }

        self.mainBundleIdentifier = mainBundleIdentifier
        observesDashboardMainApplicationTermination = true
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceApplicationDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    private func observeDashboardTerminationSignal() {
        guard !observesDashboardTerminationSignal else {
            return
        }

        observesDashboardTerminationSignal = true
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(mainAppWillTerminate(_:)),
            name: Self.mainAppWillTerminateNotification,
            object: nil
        )
    }

    nonisolated static func dashboardBundleIdentifier(forMainBundleIdentifier identifier: String?) -> String? {
        guard let identifier, !identifier.isEmpty else {
            return nil
        }
        return "\(identifier)\(TokenMeteringDashboardProcess.helperBundleIdentifierSuffix)"
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func mainApplicationWillTerminate(_ notification: Notification) {
        postMainAppWillTerminate()
        terminateDashboardHelperProcesses()
    }

    @objc private func mainAppWillTerminate(_ notification: Notification) {
        NSApp.terminate(nil)
    }

    @objc private func workspaceApplicationDidTerminate(_ notification: Notification) {
        guard let runningApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              runningApplication.bundleIdentifier == mainBundleIdentifier
        else {
            return
        }

        NSApp.terminate(nil)
    }

    private func postMainAppWillTerminate() {
        DistributedNotificationCenter.default().postNotificationName(
            Self.mainAppWillTerminateNotification,
            object: nil,
            deliverImmediately: true
        )
    }

    private func terminateDashboardHelperProcesses() {
        guard let helperBundleIdentifier = Self.dashboardBundleIdentifier(
            forMainBundleIdentifier: mainBundleIdentifier
        ) else {
            return
        }

        for runningApplication in NSWorkspace.shared.runningApplications
            where runningApplication.bundleIdentifier == helperBundleIdentifier {
            runningApplication.terminate()
        }
    }
}
