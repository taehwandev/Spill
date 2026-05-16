import AppKit
import Combine

@MainActor
final class MenuBarScanCoordinator {
    private let scanner: AXMenuBarItemScanner
    private let settings: SpillSettings
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(scanner: AXMenuBarItemScanner, settings: SpillSettings) {
        self.scanner = scanner
        self.settings = settings
    }

    func start() {
        observeSettings()
        observeApplicationActivation()
        observeWorkspaceChanges()
        observeScreenChanges()
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
    }

    func refreshNow() {
        refreshIfAllowed()
    }

    private func observeSettings() {
        settings.$autoRefreshEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleTimer()
            }
            .store(in: &cancellables)

        settings.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleTimer()
            }
            .store(in: &cancellables)
    }

    private func observeApplicationActivation() {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refreshIfAllowed()
            }
            .store(in: &cancellables)
    }

    private func observeWorkspaceChanges() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let workspaceNotifications: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification
        ]

        for name in workspaceNotifications {
            workspaceCenter.publisher(for: name)
                .sink { [weak self] _ in
                    self?.refreshIfAllowed()
                }
                .store(in: &cancellables)
        }
    }

    private func observeScreenChanges() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.refreshIfAllowed()
            }
            .store(in: &cancellables)
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = nil

        guard settings.autoRefreshEnabled else {
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: max(settings.refreshInterval, 5), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshIfAllowed()
            }
        }
    }

    private func refreshIfAllowed() {
        guard AccessibilityPermission.isTrusted else {
            scanner.clearForMissingPermission()
            return
        }

        scanner.refresh()
    }
}
