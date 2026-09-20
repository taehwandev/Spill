import AppKit

@MainActor
final class SpillPanelDismissController {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var generation = 0

    func start(
        panel: NSPanel,
        excludedScreenFrames: @escaping @MainActor () -> [NSRect] = { [] },
        isExcludedWindow: @escaping @MainActor (NSWindow) -> Bool = { _ in false },
        onDismiss: @escaping @MainActor () -> Void
    ) {
        stop()
        let activeGeneration = generation

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                guard let self, self.generation == activeGeneration,
                      Self.shouldDismiss(at: location, excludedScreenFrames: excludedScreenFrames()) else { return }
                onDismiss()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            if event.type == .keyDown, event.keyCode == KeyCode.escape {
                Task { @MainActor in
                    guard let self, self.generation == activeGeneration else { return }
                    onDismiss()
                }
                return nil
            }

            guard let eventWindow = event.window else {
                return event
            }

            let shouldDismiss = MainActor.assumeIsolated {
                Self.shouldDismiss(at: NSEvent.mouseLocation, excludedScreenFrames: excludedScreenFrames())
                    && Self.shouldDismiss(
                    forEventWindow: eventWindow,
                    panel: panel,
                    isExcludedWindow: isExcludedWindow
                )
            }
            if shouldDismiss {
                Task { @MainActor in
                    guard let self, self.generation == activeGeneration else { return }
                    onDismiss()
                }
            }

            return event
        }
    }

    /// Status-item clicks own the panel open/close decision through their button
    /// actions (mouseUp). Dismissing here on their mouseDown as well makes a single
    /// click close and immediately reopen (or open and immediately close) the panel.
    @MainActor
    static func shouldDismiss(
        forEventWindow eventWindow: NSWindow,
        panel: NSPanel,
        isExcludedWindow: (NSWindow) -> Bool
    ) -> Bool {
        if isExcludedWindow(eventWindow) {
            return false
        }

        return !isEventWindowInsidePanelSurface(eventWindow, panel: panel)
    }

    static func shouldDismiss(at location: NSPoint, excludedScreenFrames: [NSRect]) -> Bool {
        !excludedScreenFrames.contains { $0.contains(location) }
    }

    func stop() {
        generation += 1
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    static func isEventWindowInsidePanelSurface(_ eventWindow: NSWindow, panel: NSPanel) -> Bool {
        if eventWindow === panel {
            return true
        }

        if eventWindow.parent === panel {
            return true
        }

        return panel.childWindows?.contains { $0 === eventWindow } == true
    }
}

private enum KeyCode {
    static let escape: UInt16 = 53
}
