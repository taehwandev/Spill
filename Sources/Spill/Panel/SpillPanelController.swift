import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class SpillPanelController: NSObject, NSWindowDelegate {
    private let dismissController = SpillPanelDismissController()
    private let layout = SpillPanelLayout()
    private let settings: SpillSettings
    private let scanner: AXMenuBarItemScanner
    private let panelStore: PanelStore
    private let sleepGuard: SleepGuardController
    private let statusStore: SystemStatusStore
    private let aiStatusStore: AIStatusStore
    private let windowActionStore: WindowActionStore
    private let updateStore: UpdateCheckStore
    private let visibilityChanged: (Bool) -> Void
    private let settingsAction: () -> Void
    private var panel: NSPanel?
    private var anchorFrame: NSRect?
    private var isPresented = false
    private var panelRefreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        fatalError("Use init(settings:scanner:panelStore:sleepGuard:).")
    }

    init(
        settings: SpillSettings,
        scanner: AXMenuBarItemScanner,
        panelStore: PanelStore,
        statusStore: SystemStatusStore = SystemStatusStore(),
        aiStatusStore: AIStatusStore = AIStatusStore(),
        windowActionStore: WindowActionStore = WindowActionStore(),
        updateStore: UpdateCheckStore = UpdateCheckStore(),
        sleepGuard: SleepGuardController,
        visibilityChanged: @escaping (Bool) -> Void = { _ in },
        settingsAction: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self.scanner = scanner
        self.panelStore = panelStore
        self.statusStore = statusStore
        self.aiStatusStore = aiStatusStore
        self.windowActionStore = windowActionStore
        self.updateStore = updateStore
        self.sleepGuard = sleepGuard
        self.visibilityChanged = visibilityChanged
        self.settingsAction = settingsAction
        super.init()
        observeLayoutChanges()
    }

    var isVisible: Bool {
        isPresented
    }

    func prepare() {
        _ = ensurePanel()
    }

    var layoutReport: SpillPanelLayoutReport {
        guard let panel else {
            return SpillPanelLayoutReport(
                isVisible: false,
                level: .popUpMenu,
                frame: .zero,
                contentBounds: .zero,
                visibleFrame: layout.visibleFrame(for: nil)
            )
        }

        panel.contentView?.layoutSubtreeIfNeeded()

        return SpillPanelLayoutReport(
            isVisible: isPresented && panel.isVisible,
            level: panel.level,
            frame: panel.frame,
            contentBounds: panel.contentView?.bounds ?? .zero,
            visibleFrame: layout.visibleFrame(for: panel)
        )
    }

    var contentReport: SpillPanelContentReport {
        let state = currentPanelState()
        let statusModules = state.visibleStatusModules
        let statusDetailRowCount = statusModules.reduce(0) { count, module in
            count + statusStore.detailRows(for: module).count
        }
        let aiDetailRowCount = aiStatusStore.statuses.reduce(0) { count, status in
            count + SpillStatusDetailRows.rows(for: status).count
        }
        let footerItemCount = 5

        return SpillPanelContentReport(
            isVisible: isPresented && panel?.isVisible == true,
            panelState: state.readiness,
            statusModuleIDs: statusModules.map(\.rawValue),
            statusDetailRowCount: statusDetailRowCount,
            aiStatusCount: aiStatusStore.statuses.count,
            aiDetailRowCount: aiDetailRowCount,
            windowActionCount: windowActionStore.actions.count,
            menuBarActionCount: state.displayItems.count,
            footerItemCount: footerItemCount,
            showsPowerFooter: true,
            showsCountBadge: true
        )
    }

    var accessibilityReport: SpillPanelAccessibilityReport {
        panel?.contentView?.layoutSubtreeIfNeeded()

        return SpillPanelAccessibilityReport(rootElement: panel?.contentView)
    }

    func toggle() {
        if isVisible {
            hide(animated: true)
        } else {
            show()
        }
    }

    func show(anchorFrame: NSRect? = nil, dismissOnOutsideInteraction: Bool = true) {
        if let anchorFrame {
            self.anchorFrame = anchorFrame
        }

        panelStore.send(.refreshDerivedState)
        let panel = ensurePanel()
        let finalFrame = panelFrame()
        let startFrame = finalFrame.offsetBy(dx: 0, dy: 8)

        isPresented = true
        visibilityChanged(true)
        panel.setFrame(settings.useSpillAnimation ? startFrame : finalFrame, display: false)
        panel.alphaValue = settings.useSpillAnimation ? 0 : 1
        panel.orderFrontRegardless()
        schedulePanelDataRefresh()
        if dismissOnOutsideInteraction {
            dismissController.start(panel: panel) { [weak self] in
                self?.hide(animated: true)
            }
        } else {
            dismissController.stop()
        }

        animate(duration: settings.useSpillAnimation ? 0.18 : 0) {
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        } completion: { [weak self] in
            self?.resizePanelIfVisible()
        }
    }

    func hide(animated: Bool) {
        guard let panel else {
            panelStore.send(.dismissRequestHandled)
            return
        }

        isPresented = false
        visibilityChanged(false)
        panelStore.send(.dismissRequestHandled)
        panelRefreshTask?.cancel()
        dismissController.stop()

        let finalFrame = panel.frame.offsetBy(dx: 0, dy: 8)
        let duration = animated && settings.useSpillAnimation ? 0.14 : 0

        animate(duration: duration, animations: {
            panel.animator().alphaValue = 0
            panel.animator().setFrame(finalFrame, display: true)
        }, completion: { [weak self] in
            panel.orderOut(nil)
            self?.resizePanelIfVisible()
        })
    }

    private func ensurePanel() -> NSPanel {
        if let panel {
            return panel
        }

        let frame = panelFrame()
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.delegate = self
        panel.isReleasedWhenClosed = false
        // Keep the tray above menu bar/status extras while it is open.
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.minSize = SpillPanelMetrics.minimumSize

        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .popover
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 22
        visualEffectView.layer?.cornerCurve = .continuous
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 0.8
        visualEffectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor

        let hostingView = NSHostingView(
            rootView: SpillBarView(
                panelStore: panelStore,
                settings: settings,
                statusStore: statusStore,
                aiStatusStore: aiStatusStore,
                windowActionStore: windowActionStore,
                sleepGuard: sleepGuard,
                updateStore: updateStore
            ) { [weak self] in
                self?.hide(animated: true)
            } settingsAction: { [weak self] in
                self?.settingsAction()
            }
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        visualEffectView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])

        panel.contentView = visualEffectView
        self.panel = panel
        return panel
    }

    private func panelFrame() -> NSRect {
        let screen = screenForAnchor() ?? panel?.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = layout.visibleFrame(forScreen: screen)
        let fallback = layout.defaultFrame(
            in: visibleFrame,
            screen: screen,
            anchorFrame: anchorFrame,
            preferredSize: preferredPanelSize(in: visibleFrame)
        )

        return fallback
    }

    private func preferredPanelSize(in visibleFrame: NSRect) -> NSSize {
        let state = currentPanelState()
        let menuBarActionCount = state.actionItems.count

        return SpillPanelContentSizer.preferredSize(
            statusModuleCount: state.visibleStatusModules.count,
            aiStatusCount: aiStatusStore.statuses.count,
            windowActionCount: windowActionStore.actions.count,
            menuBarActionCount: menuBarActionCount,
            iconSpacing: CGFloat(settings.iconSpacing),
            visibleFrame: visibleFrame,
            showsUpdateBanner: updateStore.canOpenUpdate
        )
    }

    private func currentPanelState() -> PanelState {
        return panelStore.state
    }

    private func screenForAnchor() -> NSScreen? {
        guard let anchorFrame else {
            return nil
        }

        let anchorPoint = NSPoint(x: anchorFrame.midX, y: anchorFrame.midY)
        return NSScreen.screens.first { $0.frame.contains(anchorPoint) }
    }

    private func resizePanelIfVisible() {
        guard isPresented, let panel else {
            return
        }

        panel.setFrame(panelFrame(), display: true, animate: settings.useSpillAnimation)
    }

    private func observeLayoutChanges() {
        scanner.$items
            .dropFirst()
            .sink { [weak self] _ in
                self?.resizePanelIfVisible()
            }
            .store(in: &cancellables)

        panelStore.$state
            .dropFirst()
            .sink { [weak self] _ in
                self?.resizePanelIfVisible()
            }
            .store(in: &cancellables)

        settings.$iconSpacing
            .dropFirst()
            .sink { [weak self] _ in
                self?.resizePanelIfVisible()
            }
            .store(in: &cancellables)

        settings.$displayMode
            .dropFirst()
            .sink { [weak self] _ in
                self?.resizePanelIfVisible()
            }
            .store(in: &cancellables)

        settings.$selectedItemKeys
            .dropFirst()
            .sink { [weak self] _ in
                self?.resizePanelIfVisible()
            }
            .store(in: &cancellables)

        settings.$hiddenItemKeys
            .dropFirst()
            .sink { [weak self] _ in
                self?.resizePanelIfVisible()
            }
            .store(in: &cancellables)

        aiStatusStore.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.resizePanelIfVisible()
                }
            }
            .store(in: &cancellables)

        windowActionStore.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.resizePanelIfVisible()
                }
            }
            .store(in: &cancellables)

        updateStore.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.resizePanelIfVisible()
                }
            }
            .store(in: &cancellables)
    }

    private func refreshStatusStore() {
        let enabledModules = settings.statusModulesRequiredForRefresh
        let readsPower = true
        aiStatusStore.refreshInBackground()
        windowActionStore.refresh()
        Task { @MainActor [statusStore] in
            await statusStore.refresh(enabledModules: enabledModules, readsPower: readsPower)
        }
    }

    private func schedulePanelDataRefresh() {
        panelRefreshTask?.cancel()
        panelRefreshTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, isPresented else {
                return
            }

            refreshStatusStore()
        }
    }

    func windowWillClose(_ notification: Notification) {
        dismissController.stop()
        isPresented = false
        visibilityChanged(false)
    }

    private func animate(
        duration: TimeInterval,
        animations: @escaping () -> Void,
        completion: (@MainActor @Sendable () -> Void)? = nil
    ) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animations()
        } completionHandler: {
            Task { @MainActor in
                completion?()
            }
        }
    }
}

struct SpillPanelLayoutReport {
    let isVisible: Bool
    let level: NSWindow.Level
    let frame: NSRect
    let contentBounds: NSRect
    let visibleFrame: NSRect

    var isValid: Bool {
        isVisible
            && hasValidFrame
            && isOnScreen
            && hasCompactSize
            && contentMatchesFrame
    }

    var logLine: String {
        [
            "visible=\(isVisible)",
            "level=\(level.rawValue)",
            "frame=\(format(rect: frame))",
            "content=\(format(rect: contentBounds))",
            "visibleFrame=\(format(rect: visibleFrame))",
            "validFrame=\(hasValidFrame)",
            "onScreen=\(isOnScreen)",
            "compactSize=\(hasCompactSize)",
            "contentMatchesFrame=\(contentMatchesFrame)"
        ].joined(separator: " ")
    }

    private var hasValidFrame: Bool {
        frame.width > 0 && frame.height > 0
    }

    private var isOnScreen: Bool {
        visibleFrame.intersects(frame)
    }

    private var hasCompactSize: Bool {
        let tolerance: CGFloat = 1
        let maximumHeight = max(
            SpillPanelMetrics.minimumSize.height,
            visibleFrame.height - SpillPanelMetrics.edgeInset * 2
        )

        return frame.width >= SpillPanelMetrics.minimumSize.width - tolerance
            && frame.width <= SpillPanelMetrics.maximumWidth + tolerance
            && frame.height >= SpillPanelMetrics.minimumSize.height - tolerance
            && frame.height <= maximumHeight + tolerance
    }

    private var contentMatchesFrame: Bool {
        let tolerance: CGFloat = 1
        return abs(contentBounds.width - frame.width) <= tolerance
            && abs(contentBounds.height - frame.height) <= tolerance
    }

    private func format(rect: NSRect) -> String {
        let values = [rect.minX, rect.minY, rect.width, rect.height]
            .map { String(format: "%.1f", Double($0)) }
            .joined(separator: ",")

        return "[\(values)]"
    }
}
