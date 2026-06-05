import AppKit
import SwiftUI

@MainActor
final class TokenMeteringDashboardWindowController {
    private let autosaveName = NSWindow.FrameAutosaveName("SpillTokenMeteringDashboard")
    private let preferredSize = NSSize(width: 860, height: 680)
    private let minimumSize = NSSize(width: 720, height: 520)
    private let screenPadding: CGFloat = 32
    private let store: TokenUsageDashboardStore
    private var window: NSWindow?

    init(store: TokenUsageDashboardStore) {
        self.store = store
    }

    func show() {
        store.refresh()
        let window = ensureWindow()
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

        let contentView = TokenMeteringDashboardView(store: store)
        let window = NSWindow(
            contentRect: defaultWindowFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Spill Local Token Dashboard"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = minimumSize
        window.collectionBehavior = [.moveToActiveSpace]
        window.setFrameAutosaveName(autosaveName)
        window.contentView = NSHostingView(rootView: contentView)
        self.window = window
        return window
    }

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
