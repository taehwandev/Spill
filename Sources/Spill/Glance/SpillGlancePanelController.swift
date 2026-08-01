import AppKit
import Combine
import SwiftUI

@MainActor
final class SpillGlancePanelController: NSObject {
    private let store: SpillGlanceStore
    private let frameStore: SpillGlanceFrameStore
    private let screenProvider: SpillGlanceScreenProvider
    private let openDashboardAction: () -> Void
    private let openSettingsAction: () -> Void
    private var panel: SpillGlancePanel?
    private var dragInitialFrame: NSRect?
    private var dragInitialPointerLocation: NSPoint?
    private var dragDisplay: SpillGlanceScreenDescriptor?
    private var presentedLayoutSignature: SpillGlancePresentation.LayoutSignature?
    private var presentedShowInFullScreen: Bool?
    private var presentationObservation: AnyCancellable?
    private var notificationObservers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var isStarted = false

    init(
        store: SpillGlanceStore,
        frameStore: SpillGlanceFrameStore = SpillGlanceFrameStore(),
        screenProvider: SpillGlanceScreenProvider = SpillGlanceScreenProvider(),
        openDashboardAction: @escaping () -> Void,
        openSettingsAction: @escaping () -> Void
    ) {
        self.store = store
        self.frameStore = frameStore
        self.screenProvider = screenProvider
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
        presentedLayoutSignature = nil
        presentedShowInFullScreen = nil
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
            presentedLayoutSignature = nil
            presentedShowInFullScreen = nil
            panel?.orderOut(nil)
            return
        }

        let layoutSignature = presentation.layoutSignature
        let panel = ensurePanel()
        if presentedShowInFullScreen != presentation.showInFullScreen {
            if panel.isVisible {
                panel.orderOut(nil)
            }
            applyCollectionBehavior(
                to: panel,
                showInFullScreen: presentation.showInFullScreen
            )
            presentedShowInFullScreen = presentation.showInFullScreen
        }
        if presentedLayoutSignature != layoutSignature {
            panel.setFrame(panelFrame(for: presentation), display: panel.isVisible)
            presentedLayoutSignature = layoutSignature
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
        applyCollectionBehavior(
            to: panel,
            showInFullScreen: store.presentation.showInFullScreen
        )
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
        presentedShowInFullScreen = store.presentation.showInFullScreen
        return panel
    }

    func panelFrame(for presentation: SpillGlancePresentation) -> CGRect {
        let displays = screenProvider.descriptors()
        let fallbackDisplay = screenProvider.preferredDescriptor()
        let contentSize = SpillGlanceLayout.contentSize(
            modules: presentation.items.map(\.module),
            displayStyle: presentation.displayStyle
        )
        frameStore.migrateLegacyPlacementIfNeeded(displays: displays)
        return frameStore.restoredFrame(
            displays: displays,
            fallbackDisplay: fallbackDisplay,
            contentSize: contentSize
        )
    }

    func applyCollectionBehavior(
        to panel: NSPanel,
        showInFullScreen: Bool
    ) {
        var behavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .ignoresCycle,
            .stationary
        ]
        if showInFullScreen {
            behavior.insert(.fullScreenAuxiliary)
        }
        panel.collectionBehavior = behavior
    }
}

private extension SpillGlancePanelController {
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
                if self?.store.presentation.isVisible == true,
                   self?.store.presentation.showInFullScreen == true {
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
                if let finalDisplay = dragDisplay
                    ?? panel.screen.flatMap(screenProvider.descriptor(for:)) {
                    frameStore.save(panel.frame, display: finalDisplay)
                }
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
              let display = panel.screen.flatMap(screenProvider.descriptor(for:))
                ?? screenProvider.preferredDescriptor()
        else {
            return
        }

        dragInitialFrame = panel.frame
        dragInitialPointerLocation = NSPoint(
            x: pointerLocation.x - initialTranslation.width,
            y: pointerLocation.y + initialTranslation.height
        )
        dragDisplay = display
    }

    func movePanelOrigin(_ panel: NSPanel, to pointerLocation: NSPoint) {
        guard let initialFrame = dragInitialFrame,
              let initialPointerLocation = dragInitialPointerLocation,
              let display = dragDisplay
        else {
            return
        }

        let targetDisplay = screenProvider.descriptor(containing: pointerLocation) ?? display
        dragDisplay = targetDisplay
        let constrainedFrame = SpillGlanceLayout.draggedFrame(
            initialFrame: initialFrame,
            initialPointerLocation: initialPointerLocation,
            currentPointerLocation: pointerLocation,
            visibleFrame: targetDisplay.visibleFrame
        )
        guard panel.frame.origin != constrainedFrame.origin else {
            return
        }
        panel.setFrameOrigin(constrainedFrame.origin)
    }

    func resetDragState() {
        dragInitialFrame = nil
        dragInitialPointerLocation = nil
        dragDisplay = nil
    }
}
