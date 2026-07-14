import AppKit
import Darwin
import Foundation

@MainActor
final class TokenMeteringDashboardLifecycle: NSObject {
    static let shared = TokenMeteringDashboardLifecycle()
    static let mainAppWillTerminateNotification = Notification.Name("app.spill.main-app-will-terminate")
    private static let helperTerminationGraceInterval: TimeInterval = 1.5

    private var mainBundleIdentifier: String?
    private var observesMainApplicationTermination = false
    private var observesDashboardTerminationSignal = false
    private var observesDashboardMainApplicationTermination = false
    private var isDashboardProcessTerminationRequested = false

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
}

extension TokenMeteringDashboardLifecycle {
    @objc private func mainApplicationWillTerminate(_ notification: Notification) {
        postMainAppWillTerminate()
        terminateDashboardHelperProcesses()
    }

    @objc private func mainAppWillTerminate(_ notification: Notification) {
        terminateCurrentDashboardProcess()
    }

    @objc private func workspaceApplicationDidTerminate(_ notification: Notification) {
        guard let runningApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              runningApplication.bundleIdentifier == mainBundleIdentifier
        else {
            return
        }

        terminateCurrentDashboardProcess()
    }

    private func postMainAppWillTerminate() {
        DistributedNotificationCenter.default().postNotificationName(
            Self.mainAppWillTerminateNotification,
            object: nil,
            deliverImmediately: true
        )
    }
}

extension TokenMeteringDashboardLifecycle {
    private func terminateDashboardHelperProcesses() {
        guard let helperBundleIdentifier = Self.dashboardBundleIdentifier(
            forMainBundleIdentifier: mainBundleIdentifier
        ) else {
            return
        }

        let helperApplications = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == helperBundleIdentifier
        }
        guard !helperApplications.isEmpty else {
            return
        }

        for runningApplication in helperApplications {
            runningApplication.terminate()
        }

        waitForDashboardHelperTermination(helperApplications)

        for runningApplication in helperApplications where !runningApplication.isTerminated {
            runningApplication.forceTerminate()
        }
    }

    private func waitForDashboardHelperTermination(_ helperApplications: [NSRunningApplication]) {
        let deadline = Date().addingTimeInterval(Self.helperTerminationGraceInterval)
        while Date() < deadline,
              helperApplications.contains(where: { !$0.isTerminated }) {
            _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }
}

extension TokenMeteringDashboardLifecycle {
    func terminateCurrentDashboardProcess() {
        guard TokenMeteringDashboardProcess.isDashboardProcess else {
            NSApp.terminate(nil)
            return
        }

        prepareWindowsForFastTermination()
        scheduleCurrentProcessKillFallback()
        NSApp.terminate(nil)
    }

    private func prepareWindowsForFastTermination() {
        for window in NSApp.windows {
            window.isRestorable = false
            window.orderOut(nil)
        }
    }

    private func scheduleCurrentProcessKillFallback() {
        guard !isDashboardProcessTerminationRequested else {
            return
        }

        isDashboardProcessTerminationRequested = true
        let processID = Darwin.getpid()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + Self.helperTerminationGraceInterval) {
            SpillCrashReporter.markUncleanShutdownPending(processRole: "token_dashboard")
            Darwin.kill(processID, SIGKILL)
        }
    }
}
