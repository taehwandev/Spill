import AppKit

@MainActor
struct SpillPanelLayout {
    func visibleFrame(for panel: NSPanel?) -> NSRect {
        let screen = panel?.screen ?? NSScreen.main ?? NSScreen.screens.first
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 600, height: 400)
    }

    func defaultFrame(
        in visibleFrame: NSRect,
        screen: NSScreen?
    ) -> NSRect {
        let maximumWidth = min(
            SpillPanelMetrics.maximumWidth,
            visibleFrame.width - SpillPanelMetrics.edgeInset * 2
        )
        let width = min(SpillPanelMetrics.defaultWidth, maximumWidth)
        let geometry = MenuBarNotchGeometry(screen: screen)
        let anchorX = geometry.hasHardwareNotch ? geometry.notchFrame.midX : visibleFrame.midX
        let minX = visibleFrame.minX + SpillPanelMetrics.edgeInset
        let maxX = visibleFrame.maxX - SpillPanelMetrics.edgeInset - width
        let x = (anchorX - width / 2).clamped(to: minX...max(minX, maxX))
        let y = visibleFrame.maxY - SpillPanelMetrics.defaultHeight - 10

        return NSRect(x: x, y: y, width: width, height: SpillPanelMetrics.defaultHeight)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
