import AppKit
import Combine
import SwiftUI

@MainActor
final class SpillGlancePanelController: NSObject {
    private let store: SpillGlanceStore
    private let frameStore: SpillGlanceFrameStore
    private let openDashboardAction: () -> Void
    private let openSettingsAction: () -> Void
    private var panel: SpillGlancePanel?
    private var dragInitialFrame: NSRect?
    private var dragInitialPointerLocation: NSPoint?
    private var dragVisibleFrame: NSRect?
    private var presentedModules: [SpillGlanceModule]?
    private var presentationObservation: AnyCancellable?
    private var notificationObservers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var isStarted = false

    init(
        store: SpillGlanceStore,
        frameStore: SpillGlanceFrameStore = SpillGlanceFrameStore(),
        openDashboardAction: @escaping () -> Void,
        openSettingsAction: @escaping () -> Void
    ) {
        self.store = store
        self.frameStore = frameStore
        self.openDashboardAction = openDashboardAction
        self.openSettingsAction = openSettingsAction
        super.init()
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func start() {
        guard !isStarted else {
            updatePanel(for: store.presentation)
            return
        }

        isStarted = true
        presentationObservation = store.$presentation
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                self.updatePanel(for: self.store.presentation)
            }

        observeDisplayChanges()
        updatePanel(for: store.presentation)
    }

    func stop() {
        guard isStarted else {
            return
        }

        isStarted = false
        presentationObservation = nil
        notificationObservers.forEach { observation in
            observation.center.removeObserver(observation.token)
        }
        notificationObservers.removeAll()
        resetDragState()
        presentedModules = nil
        panel?.orderOut(nil)
    }

    func reposition() {
        guard store.presentation.isVisible, let panel else {
            return
        }

        panel.setFrame(
            panelFrame(for: store.presentation),
            display: panel.isVisible,
            animate: false
        )
    }
}

private extension SpillGlancePanelController {
    func updatePanel(for presentation: SpillGlancePresentation) {
        guard isStarted, presentation.isVisible else {
            presentedModules = nil
            panel?.orderOut(nil)
            return
        }

        let modules = presentation.items.map(\.module)
        let panel = ensurePanel()
        if presentedModules != modules {
            panel.setFrame(panelFrame(for: presentation), display: panel.isVisible)
            presentedModules = modules
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func ensurePanel() -> SpillGlancePanel {
        if let panel {
            return panel
        }

        let frame = panelFrame(for: store.presentation)
        let panel = SpillGlancePanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .none
        panel.title = "Spill Glance"
        panel.contentView = SpillGlanceHostingView(
            rootView: SpillGlanceView(
                store: store,
                openDashboardAction: openDashboardAction,
                openSettingsAction: openSettingsAction,
                dragAction: { [weak self] phase in
                    self?.handleDrag(phase)
                }
            )
        )

        self.panel = panel
        return panel
    }

    func panelFrame(for presentation: SpillGlancePresentation) -> CGRect {
        let screen = preferredScreen()
        let contentSize = SpillGlanceLayout.contentSize(
            modules: presentation.items.map(\.module)
        )
        let fallback = SpillGlanceLayout.panelFrame(
            contentSize: contentSize,
            visibleFrame: screen?.visibleFrame ?? .zero
        )
        return frameStore.restoredFrame(
            visibleFrames: NSScreen.screens.map(\.visibleFrame),
            fallback: fallback
        )
    }

    func preferredScreen() -> NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }

    func observeDisplayChanges() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSApplication.didChangeScreenParametersNotification,
            NSApplication.didBecomeActiveNotification
        ]

        notificationObservers.append(contentsOf: names.map { name in
            let token = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.reposition()
                }
            }
            return (center, token)
        })

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let token = workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reposition()
                if self?.store.presentation.isVisible == true {
                    self?.panel?.orderFrontRegardless()
                }
            }
        }
        notificationObservers.append((workspaceCenter, token))
    }

}

private extension SpillGlancePanelController {
    func handleDrag(_ phase: SpillGlanceDragPhase) {
        guard let panel else {
            return
        }

        switch phase {
        case let .changed(translation):
            let pointerLocation = NSEvent.mouseLocation
            beginDragIfNeeded(
                panel: panel,
                initialTranslation: translation,
                pointerLocation: pointerLocation
            )
            movePanelOrigin(panel, to: pointerLocation)
        case .ended:
            if dragInitialFrame != nil {
                movePanelOrigin(panel, to: NSEvent.mouseLocation)
                frameStore.save(panel.frame)
            }
            resetDragState()
        }
    }

    func beginDragIfNeeded(
        panel: NSPanel,
        initialTranslation: CGSize,
        pointerLocation: NSPoint
    ) {
        guard dragInitialFrame == nil,
              let visibleFrame = panel.screen?.visibleFrame ?? preferredScreen()?.visibleFrame
        else {
            return
        }

        dragInitialFrame = panel.frame
        dragInitialPointerLocation = NSPoint(
            x: pointerLocation.x - initialTranslation.width,
            y: pointerLocation.y + initialTranslation.height
        )
        dragVisibleFrame = visibleFrame
    }

    func movePanelOrigin(_ panel: NSPanel, to pointerLocation: NSPoint) {
        guard let initialFrame = dragInitialFrame,
              let initialPointerLocation = dragInitialPointerLocation,
              let visibleFrame = dragVisibleFrame
        else {
            return
        }

        let targetVisibleFrame = screenVisibleFrame(containing: pointerLocation) ?? visibleFrame
        dragVisibleFrame = targetVisibleFrame
        let constrainedFrame = SpillGlanceLayout.draggedFrame(
            initialFrame: initialFrame,
            initialPointerLocation: initialPointerLocation,
            currentPointerLocation: pointerLocation,
            visibleFrame: targetVisibleFrame
        )
        guard panel.frame.origin != constrainedFrame.origin else {
            return
        }
        panel.setFrameOrigin(constrainedFrame.origin)
    }

    func screenVisibleFrame(containing pointerLocation: NSPoint) -> NSRect? {
        NSScreen.screens.first {
            NSMouseInRect(pointerLocation, $0.frame, false)
        }?.visibleFrame
    }

    func resetDragState() {
        dragInitialFrame = nil
        dragInitialPointerLocation = nil
        dragVisibleFrame = nil
    }
}
