import AppKit

extension NSRect {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> NSRect {
        NSRect(x: origin.x + dx, y: origin.y + dy, width: size.width, height: size.height)
    }

    func constrained(to visibleFrame: NSRect, minimumSize: NSSize, edgeInset: CGFloat) -> NSRect {
        let maxWidth = max(minimumSize.width, visibleFrame.width - edgeInset * 2)
        let maxHeight = max(minimumSize.height, visibleFrame.height - edgeInset * 2)
        let width = min(max(size.width, minimumSize.width), maxWidth)
        let height = min(max(size.height, minimumSize.height), maxHeight)

        let minX = visibleFrame.minX + edgeInset
        let maxX = visibleFrame.maxX - edgeInset - width
        let minY = visibleFrame.minY + edgeInset
        let maxY = visibleFrame.maxY - edgeInset - height
        let x = origin.x.clamped(to: minX...max(minX, maxX))
        let y = origin.y.clamped(to: minY...max(minY, maxY))

        return NSRect(x: x, y: y, width: width, height: height)
    }
}
