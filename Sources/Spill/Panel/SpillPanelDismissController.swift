import AppKit

@MainActor
final class SpillPanelDismissController {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start(panel: NSPanel, onDismiss: @escaping @MainActor () -> Void) {
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { _ in
            Task { @MainActor in
                onDismiss()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { event in
            if event.type == .keyDown, event.keyCode == KeyCode.escape {
                Task { @MainActor in
                    onDismiss()
                }
                return nil
            }

            guard let eventWindow = event.window else {
                return event
            }

            if !Self.isEventWindowInsidePanelSurface(eventWindow, panel: panel) {
                Task { @MainActor in
                    onDismiss()
                }
            }

            return event
        }
    }

    func stop() {
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
