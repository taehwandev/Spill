import AppKit
import Combine
import SwiftUI

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private let autosaveName = NSWindow.FrameAutosaveName("SpillPreferences")
    private let preferredSize = NSSize(width: 720, height: 560)
    private let minimumSize = NSSize(width: 640, height: 480)
    private let screenPadding: CGFloat = 32
    private let settings: SpillSettings
    private let scanner: AXMenuBarItemScanner
    private let updateStore: UpdateCheckStore
    private let tokenUsageStore: TokenUsageStore
    private let tokenHistoryImportCoordinator: TokenUsageHistoryImportCoordinator
    private let aiStatusStore: AIStatusStore
    private let showPanelAction: () -> Void
    private let openTokenDashboardAction: () -> Void
    private let preparePrivateUsageUploadAction: @MainActor () async -> Void
    private let navigationState = PreferencesNavigationState()
    private var window: NSWindow?
    private var languageObservation: AnyCancellable?
    private var appearanceObservation: AnyCancellable?

    init(
        settings: SpillSettings,
        scanner: AXMenuBarItemScanner,
        updateStore: UpdateCheckStore,
        tokenUsageStore: TokenUsageStore,
        tokenHistoryImportCoordinator: TokenUsageHistoryImportCoordinator,
        aiStatusStore: AIStatusStore,
        showPanelAction: @escaping () -> Void,
        openTokenDashboardAction: @escaping () -> Void,
        preparePrivateUsageUploadAction: @escaping @MainActor () async -> Void = {}
    ) {
        self.settings = settings
        self.scanner = scanner
        self.updateStore = updateStore
        self.tokenUsageStore = tokenUsageStore
        self.tokenHistoryImportCoordinator = tokenHistoryImportCoordinator
        self.aiStatusStore = aiStatusStore
        self.showPanelAction = showPanelAction
        self.openTokenDashboardAction = openTokenDashboardAction
        self.preparePrivateUsageUploadAction = preparePrivateUsageUploadAction
        super.init()
    }
}

extension PreferencesWindowController {
    func show(selectedTab: String? = nil) {
        if let selectedTab {
            navigationState.selectedTab = selectedTab
        }

        let window = ensureWindow()
        window.title = PreferencesL10n.text(.preferencesWindowTitle, appLanguage: settings.appLanguage)
        constrainToVisibleScreen(window)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeKey()
    }

    private func ensureWindow() -> NSWindow {
        if let window {
            return window
        }

        let contentView = PreferencesView(
            settings: settings,
            scanner: scanner,
            updateStore: updateStore,
            navigationState: navigationState,
            tokenUsageStore: tokenUsageStore,
            tokenHistoryImportCoordinator: tokenHistoryImportCoordinator,
            aiStatusStore: aiStatusStore,
            showPanelAction: showPanelAction,
            openTokenDashboardAction: openTokenDashboardAction,
            preparePrivateUsageUploadAction: preparePrivateUsageUploadAction
        )
        let window = NSWindow(
            contentRect: defaultWindowFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = PreferencesL10n.text(.preferencesWindowTitle, appLanguage: settings.appLanguage)
        window.appearance = settings.appearanceTheme.nsAppearance
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = minimumSize
        window.collectionBehavior = [.moveToActiveSpace]
        window.setFrameAutosaveName(autosaveName)
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self
        self.window = window
        languageObservation = settings.$appLanguage.sink { [weak self] appLanguage in
            self?.window?.title = PreferencesL10n.text(.preferencesWindowTitle, appLanguage: appLanguage)
        }
        appearanceObservation = settings.$appearanceTheme.sink { [weak self] theme in
            self?.window?.appearance = theme.nsAppearance
        }
        return window
    }
}

extension PreferencesWindowController {
    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window
        else {
            return
        }

        releaseWindowContent()
    }

    func prepareForTermination() {
        window?.isRestorable = false
        window?.orderOut(nil)
        releaseWindowContent()
    }

    private func releaseWindowContent() {
        languageObservation?.cancel()
        languageObservation = nil
        appearanceObservation?.cancel()
        appearanceObservation = nil

        let window = self.window
        self.window = nil
        window?.delegate = nil
        window?.contentView = nil
    }
}

private extension PreferencesWindowController {
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
