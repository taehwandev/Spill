import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class SpillPanelController: NSObject, NSWindowDelegate {
    private let dismissController = SpillPanelDismissController()
    private let layout = SpillPanelLayout()
    private let settings: SpillSettings
    private let panelStore: PanelStore
    private let sleepGuard: SleepGuardController
    private let statusStore: SystemStatusStore
    private let aiStatusStore: AIStatusStore
    private let cloudServiceStatusStore: CloudServiceStatusStore
    private let tokenUsageDashboardStore: TokenUsageDashboardStore
    private let windowActionStore: WindowActionStore
    private let updateStore: UpdateCheckStore
    private let visibilityChanged: (Bool) -> Void
    private let settingsAction: () -> Void
    private let tokenMeteringDetailAction: () -> Void
    var dismissExcludedWindowsProvider: @MainActor () -> [NSWindow] = { [] }
    private var panel: NSPanel?
    private weak var panelVisualEffectView: NSVisualEffectView?
    private var anchorFrame: NSRect?
    private var isPresented = false
    private var panelRefreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var presentationGeneration = 0
    private var layoutResizeScheduled = false

    override init() {
        fatalError("Use init(settings:panelStore:sleepGuard:).")
    }

    init(
        settings: SpillSettings,
        panelStore: PanelStore,
        statusStore: SystemStatusStore = SystemStatusStore(), aiStatusStore: AIStatusStore = AIStatusStore(),
        cloudServiceStatusStore: CloudServiceStatusStore = CloudServiceStatusStore(),
        tokenUsageDashboardStore: TokenUsageDashboardStore,
        windowActionStore: WindowActionStore = WindowActionStore(), updateStore: UpdateCheckStore = UpdateCheckStore(),
        sleepGuard: SleepGuardController,
        visibilityChanged: @escaping (Bool) -> Void = { _ in },
        settingsAction: @escaping () -> Void = {},
        tokenMeteringDetailAction: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self.panelStore = panelStore
        self.statusStore = statusStore
        self.aiStatusStore = aiStatusStore
        self.cloudServiceStatusStore = cloudServiceStatusStore
        self.tokenUsageDashboardStore = tokenUsageDashboardStore
        self.windowActionStore = windowActionStore
        self.updateStore = updateStore
        self.sleepGuard = sleepGuard
        self.visibilityChanged = visibilityChanged
        self.settingsAction = settingsAction
        self.tokenMeteringDetailAction = tokenMeteringDetailAction
        super.init()
        observeLayoutChanges()
    }

    var isVisible: Bool {
        isPresented
    }

    func prepare() {
        _ = ensurePanel()
    }
}

extension SpillPanelController {
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
        let footerItemCount = 5

        return SpillPanelContentReport(
            isVisible: isPresented && panel?.isVisible == true,
            statusModuleIDs: statusModules.map(\.rawValue),
            statusDetailRowCount: statusDetailRowCount,
            aiStatusCount: aiStatusStore.statuses.count,
            windowActionCount: windowActionStore.actions.count,
            footerItemCount: footerItemCount,
            showsPowerFooter: true
        )
    }

    var accessibilityReport: SpillPanelAccessibilityReport {
        panel?.contentView?.layoutSubtreeIfNeeded()

        return SpillPanelAccessibilityReport(rootElement: panel?.contentView)
    }
}

extension SpillPanelController {
    func toggle() {
        if isVisible {
            hide(animated: true)
        } else {
            show()
        }
    }

    func show(
        anchorFrame: NSRect? = nil,
        dismissOnOutsideInteraction: Bool = true,
        tokenUsageAlreadyRefreshed: Bool = false
    ) {
        if let anchorFrame {
            self.anchorFrame = anchorFrame
        }

        panelStore.send(.refreshDerivedState)
        let panel = ensurePanel()
        let finalFrame = panelFrame()
        let startFrame = finalFrame.offsetBy(dx: 0, dy: 8)

        presentationGeneration += 1
        let generation = presentationGeneration
        isPresented = true
        visibilityChanged(true)
        panel.setFrame(settings.useSpillAnimation ? startFrame : finalFrame, display: false)
        panel.alphaValue = settings.useSpillAnimation ? 0 : 1
        panel.orderFrontRegardless()
        schedulePanelDataRefresh(refreshTokenUsage: !tokenUsageAlreadyRefreshed)
        if dismissOnOutsideInteraction {
            dismissController.start(
                panel: panel,
                excludedScreenFrames: { [weak self] in
                    self?.dismissExcludedWindowsProvider().map(\.frame) ?? []
                },
                isExcludedWindow: { [weak self] window in
                    self?.dismissExcludedWindowsProvider().contains { $0 === window } == true
                }
            ) { [weak self] in
                self?.hide(animated: true)
            }
        } else {
            dismissController.stop()
        }

        animate(duration: settings.useSpillAnimation ? 0.18 : 0) {
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        } completion: { [weak self] in
            guard let self, presentationGeneration == generation, isPresented else { return }
            resizePanelIfVisible()
        }
    }

    func hide(animated: Bool) {
        guard let panel else {
            return
        }

        presentationGeneration += 1
        let generation = presentationGeneration
        isPresented = false
        visibilityChanged(false)
        panelRefreshTask?.cancel()
        dismissController.stop()

        let finalFrame = panel.frame.offsetBy(dx: 0, dy: 8)
        let duration = animated && settings.useSpillAnimation ? 0.14 : 0

        animate(duration: duration, animations: {
            panel.animator().alphaValue = 0
            panel.animator().setFrame(finalFrame, display: true)
        }, completion: { [weak self] in
            guard let self, presentationGeneration == generation, !isPresented else { return }
            panel.orderOut(nil)
        })
    }
}

extension SpillPanelController {
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
        panel.isRestorable = false
        // Keep the tray above menu bar/status extras while it is open.
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.minSize = SpillPanelMetrics.minimumSize
        panel.appearance = settings.appearanceTheme.nsAppearance

        let visualEffectView = SpillPanelVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .popover
        visualEffectView.state = .active
        visualEffectView.layer?.borderWidth = 0.8
        panelVisualEffectView = visualEffectView
        applyPanelBorderColor()

        let hostingView = NSHostingView(
            rootView: SpillBarView(
                panelStore: panelStore,
                settings: settings,
                statusStore: statusStore,
                aiStatusStore: aiStatusStore,
                cloudServiceStatusStore: cloudServiceStatusStore,
                tokenUsageDashboardStore: tokenUsageDashboardStore,
                windowActionStore: windowActionStore,
                sleepGuard: sleepGuard,
                updateStore: updateStore
            ) { [weak self] in
                self?.settingsAction()
            } tokenMeteringDetailAction: { [weak self] in
                self?.tokenMeteringDetailAction()
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
}

extension SpillPanelController {
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

        return SpillPanelContentSizer.preferredSize(
            statusModuleCount: state.visibleStatusModules.count,
            showsTokenMetering: true,
            windowActionCount: windowActionStore.actions.count,
            visibleFrame: visibleFrame,
            showsUpdateBanner: updateStore.showsDashboardUpdateStatus
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
        panel.invalidateShadow()
    }

    private func applyPanelBorderColor() {
        guard let layer = panelVisualEffectView?.layer else {
            return
        }
        let appearance = panel?.effectiveAppearance ?? NSApp.effectiveAppearance
        appearance.performAsCurrentDrawingAppearance {
            layer.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        }
    }
}

extension SpillPanelController {
    private func observeLayoutChanges() {
        let changes: [AnyPublisher<Void, Never>] = [
            panelStore.$state.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$hiddenLocalAIToolKinds.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            aiStatusStore.statusCountDidChange.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            cloudServiceStatusStore.objectWillChange.eraseToAnyPublisher(),
            windowActionStore.objectWillChange.eraseToAnyPublisher(),
            updateStore.objectWillChange.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(changes)
            .sink { [weak self] _ in self?.schedulePanelResize() }
            .store(in: &cancellables)
        settings.$appearanceTheme.dropFirst()
            .sink { [weak self] theme in
                self?.panel?.appearance = theme.nsAppearance
                self?.applyPanelBorderColor()
            }
            .store(in: &cancellables)
    }

    private func schedulePanelResize() {
        guard !layoutResizeScheduled else { return }
        layoutResizeScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.layoutResizeScheduled = false
            self?.resizePanelIfVisible()
        }
    }
}

extension SpillPanelController {
    private func refreshPanelData(refreshTokenUsage: Bool = true) {
        aiStatusStore.refreshInBackground()
        if refreshTokenUsage {
            tokenUsageDashboardStore.refreshPanelSummary()
        }
        windowActionStore.refresh()
    }

    private func schedulePanelDataRefresh(refreshTokenUsage: Bool = true) {
        panelRefreshTask?.cancel()
        panelRefreshTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self, isPresented else {
                return
            }

            refreshPanelData(refreshTokenUsage: refreshTokenUsage)
        }
    }
}

extension SpillPanelController {
    func windowWillClose(_ notification: Notification) {
        presentationGeneration += 1
        panelRefreshTask?.cancel()
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
