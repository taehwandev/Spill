import AppKit

@MainActor
struct SpillPanelLayout {
    func visibleFrame(for panel: NSPanel?) -> NSRect {
        let screen = panel?.screen ?? NSScreen.main ?? NSScreen.screens.first
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 600, height: 400)
    }

    func visibleFrame(forScreen screen: NSScreen?) -> NSRect {
        screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 600, height: 400)
    }

    func defaultFrame(
        in visibleFrame: NSRect,
        screen: NSScreen?,
        anchorFrame: NSRect? = nil,
        preferredSize: NSSize? = nil
    ) -> NSRect {
        let preferredSize = preferredSize ?? NSSize(
            width: SpillPanelMetrics.defaultWidth,
            height: SpillPanelMetrics.defaultHeight
        )
        let width = min(
            max(preferredSize.width, SpillPanelMetrics.minimumSize.width),
            SpillPanelContentSizer.preferredWidth(visibleFrame: visibleFrame)
        )
        let height = SpillPanelContentSizer.boundedHeight(preferredSize.height, visibleFrame: visibleFrame)
        let geometry = MenuBarNotchGeometry(screen: screen)
        let validAnchorFrame = validMenuBarAnchor(anchorFrame, visibleFrame: visibleFrame)
        let anchorX = validAnchorFrame?.midX ?? (geometry.hasHardwareNotch ? geometry.notchFrame.midX : visibleFrame.midX)
        let minX = visibleFrame.minX + SpillPanelMetrics.edgeInset
        let maxX = visibleFrame.maxX - SpillPanelMetrics.edgeInset - width
        let x = (anchorX - width / 2).clamped(to: minX...max(minX, maxX))
        let fallbackY = visibleFrame.maxY - height - 10
        let anchoredY = validAnchorFrame.map { min($0.minY - 8, visibleFrame.maxY - 8) - height }
        let minY = visibleFrame.minY + SpillPanelMetrics.edgeInset
        let maxY = visibleFrame.maxY - SpillPanelMetrics.edgeInset - height
        let y = (anchoredY ?? fallbackY).clamped(to: minY...max(minY, maxY))

        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func validMenuBarAnchor(_ anchorFrame: NSRect?, visibleFrame: NSRect) -> NSRect? {
        guard let anchorFrame,
              anchorFrame.width > 0,
              anchorFrame.height > 0,
              anchorFrame.maxX >= visibleFrame.minX,
              anchorFrame.minX <= visibleFrame.maxX,
              anchorFrame.minY >= visibleFrame.midY
        else {
            return nil
        }

        return anchorFrame
    }
}
