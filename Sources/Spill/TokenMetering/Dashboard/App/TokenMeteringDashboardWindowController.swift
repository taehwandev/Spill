import AppKit
import SwiftUI

@MainActor
final class TokenMeteringDashboardWindowController: NSObject, NSWindowDelegate {
    private let autosaveName = NSWindow.FrameAutosaveName("SpillTokenMeteringDashboard")
    private let preferredSize = TokenMeteringDashboardWindowMetrics.preferredContentSize
    private let minimumSize = TokenMeteringDashboardWindowMetrics.minimumContentSize
    private let screenPadding: CGFloat = 32
    private let store: TokenUsageDashboardStore
    private let cloudServiceStatusStore: CloudServiceStatusStore
    private let aiStatusStore: AIStatusStore
    private let settings: SpillSettings
    private let deferredRefreshDelayNanoseconds: UInt64 = 1_500_000_000
    private let aiStatusRefreshIntervalNanoseconds: UInt64 = 8_000_000_000
    private let tokenDataRefreshIntervalNanoseconds: UInt64 = 15_000_000_000
    private let refreshAction: () -> Void
    private let settingsAction: () -> Void
    private let developerOptionsAction: () -> Void
    private let closeAction: () -> Void
    private let syncsVisibleAIToolsInView: Bool
    private var window: NSWindow?
    private var deferredRefreshTask: Task<Void, Never>?
    private var aiStatusRefreshTask: Task<Void, Never>?
    private var tokenDataRefreshTask: Task<Void, Never>?
    private var isPreparingForTermination = false

    init(
        store: TokenUsageDashboardStore,
        cloudServiceStatusStore: CloudServiceStatusStore = CloudServiceStatusStore(),
        aiStatusStore: AIStatusStore = AIStatusStore(),
        settings: SpillSettings = .shared,
        refreshAction: @escaping () -> Void = {},
        settingsAction: @escaping () -> Void = {},
        developerOptionsAction: @escaping () -> Void = {},
        closeAction: @escaping () -> Void = {},
        syncsVisibleAIToolsInView: Bool = true
    ) {
        self.store = store
        self.cloudServiceStatusStore = cloudServiceStatusStore
        self.aiStatusStore = aiStatusStore
        self.settings = settings
        self.refreshAction = refreshAction
        self.settingsAction = settingsAction
        self.developerOptionsAction = developerOptionsAction
        self.closeAction = closeAction
        self.syncsVisibleAIToolsInView = syncsVisibleAIToolsInView
        super.init()
    }

    func show() {
        let window = ensureWindow()
        updateWindowTitle(window)
        constrainToVisibleScreen(window)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeKey()
        aiStatusStore.refreshInBackground()
        store.refreshAsyncIfIdle()
        startAIStatusRefreshLoop()
        startTokenDataRefreshLoop()
        scheduleDeferredCollectionRequest()
    }
}

extension TokenMeteringDashboardWindowController {
    private func scheduleDeferredCollectionRequest() {
        deferredRefreshTask?.cancel()
        deferredRefreshTask = Task { @MainActor [weak self] in
            let delay = self?.deferredRefreshDelayNanoseconds ?? 1_500_000_000
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard let self else {
                return
            }
            self.refreshAction()
        }
    }

    private func startAIStatusRefreshLoop() {
        aiStatusRefreshTask?.cancel()
        aiStatusRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        nanoseconds: self?.aiStatusRefreshIntervalNanoseconds ?? 8_000_000_000
                    )
                } catch {
                    return
                }

                guard let self, self.window?.isVisible == true else {
                    return
                }

                self.aiStatusStore.refreshInBackground()
            }
        }
    }

    private func startTokenDataRefreshLoop() {
        tokenDataRefreshTask?.cancel()
        tokenDataRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        nanoseconds: self?.tokenDataRefreshIntervalNanoseconds ?? 15_000_000_000
                    )
                } catch {
                    return
                }

                guard let self, self.window?.isVisible == true else {
                    return
                }

                self.requestTokenDataRefresh()
            }
        }
    }

    private func requestTokenDataRefresh() {
        guard !store.isDashboardRefreshInProgress else {
            return
        }
        refreshAction()
        store.refreshAsync()
    }
}

extension TokenMeteringDashboardWindowController {
    private func ensureWindow() -> NSWindow {
        if let window {
            return window
        }

        let contentView = TokenMeteringDashboardView(
            store: store,
            cloudServiceStatusStore: cloudServiceStatusStore,
            aiStatusStore: aiStatusStore,
            settings: settings,
            refreshAction: refreshAction,
            settingsAction: settingsAction,
            developerOptionsAction: developerOptionsAction,
            syncsVisibleAITools: syncsVisibleAIToolsInView,
            titleDidChange: { [weak self] in
                self?.updateWindowTitle()
            }
        )
        let window = NSWindow(
            contentRect: defaultWindowFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        updateWindowTitle(window)
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentMinSize = minimumSize
        window.collectionBehavior = [.moveToActiveSpace]
        window.setFrameAutosaveName(autosaveName)
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        cancelRefreshTasks()
        aiStatusStore.cancelRefresh()
        guard !isPreparingForTermination else {
            return
        }
        closeAction()
    }

    func prepareForTermination() {
        isPreparingForTermination = true
        cancelRefreshTasks()
        aiStatusStore.cancelRefresh()
        window?.isRestorable = false
        window?.orderOut(nil)
    }

    func prepareVisibleRenderForSmokeTest() -> CGSize? {
        guard let window, window.isVisible, let contentView = window.contentView else {
            return nil
        }

        contentView.layoutSubtreeIfNeeded()
        contentView.displayIfNeeded()
        window.displayIfNeeded()
        return contentView.bounds.size
    }

    private func cancelRefreshTasks() {
        aiStatusRefreshTask?.cancel()
        aiStatusRefreshTask = nil
        tokenDataRefreshTask?.cancel()
        tokenDataRefreshTask = nil
        deferredRefreshTask?.cancel()
        deferredRefreshTask = nil
    }

    private func updateWindowTitle(_ window: NSWindow? = nil) {
        let target = window ?? self.window
        target?.title = TokenMeteringL10n.text(
            .dashboardTitle,
            language: TokenMeteringLanguage.current(appLanguage: settings.appLanguage)
        )
    }
}

extension TokenMeteringDashboardWindowController {
    private var defaultWindowFrame: NSRect {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let size = fittedSize(for: visibleFrame)
        return NSRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func constrainToVisibleScreen(_ window: NSWindow) {
        let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        var frame = window.frame
        let maximumSize = maximumWindowSize(for: visibleFrame)

        frame.size.width = min(max(frame.size.width, minimumSize.width), maximumSize.width)
        frame.size.height = min(max(frame.size.height, minimumSize.height), maximumSize.height)
        frame.origin.x = clamped(
            frame.origin.x,
            minimum: visibleFrame.minX + screenPadding,
            maximum: visibleFrame.maxX - screenPadding - frame.size.width
        )
        frame.origin.y = clamped(
            frame.origin.y,
            minimum: visibleFrame.minY + screenPadding,
            maximum: visibleFrame.maxY - screenPadding - frame.size.height
        )

        window.setFrame(frame, display: false)
    }

    private func fittedSize(for visibleFrame: NSRect) -> NSSize {
        let maximumSize = maximumWindowSize(for: visibleFrame)
        return NSSize(
            width: min(preferredSize.width, maximumSize.width),
            height: min(preferredSize.height, maximumSize.height)
        )
    }

    private func maximumWindowSize(for visibleFrame: NSRect) -> NSSize {
        NSSize(
            width: max(minimumSize.width, visibleFrame.width - screenPadding * 2),
            height: max(minimumSize.height, visibleFrame.height - screenPadding * 2)
        )
    }

    private func clamped(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard maximum >= minimum else {
            return minimum
        }

        return min(max(value, minimum), maximum)
    }
}
