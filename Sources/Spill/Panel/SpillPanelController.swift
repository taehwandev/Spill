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
    private let visibilityChanged: (Bool) -> Void
    private var panel: NSPanel?
    private var isPresented = false
    private var cancellables = Set<AnyCancellable>()

    override init() {
        fatalError("Use init(settings:).")
    }

    init(
        settings: SpillSettings,
        scanner: AXMenuBarItemScanner,
        visibilityChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.settings = settings
        self.scanner = scanner
        self.visibilityChanged = visibilityChanged
        super.init()
        observeLayoutChanges()
    }

    var isVisible: Bool {
        isPresented
    }

    func toggle() {
        if isVisible {
            hide(animated: true)
        } else {
            show()
        }
    }

    func show() {
        let panel = ensurePanel()
        let finalFrame = panelFrame()
        let startFrame = finalFrame.offsetBy(dx: 0, dy: 8)

        isPresented = true
        visibilityChanged(true)
        panel.setFrame(settings.useSpillAnimation ? startFrame : finalFrame, display: false)
        panel.alphaValue = settings.useSpillAnimation ? 0 : 1
        panel.orderFrontRegardless()
        dismissController.start(panel: panel) { [weak self] in
            self?.hide(animated: true)
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
            return
        }

        isPresented = false
        visibilityChanged(false)
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
        panel.level = .statusBar
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
            rootView: SpillBarView(settings: settings, scanner: scanner) { [weak self] in
                self?.hide(animated: true)
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
        let screen = panel?.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = layout.visibleFrame(for: panel)
        let fallback = layout.defaultFrame(in: visibleFrame, screen: screen)

        return fallback
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
