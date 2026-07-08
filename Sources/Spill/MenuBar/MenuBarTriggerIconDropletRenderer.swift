import AppKit

@MainActor
enum MenuBarTriggerIconDropletRenderer {
    private static let keyColor = NSColor(calibratedRed: 0.0863, green: 0.7451, blue: 0.5451, alpha: 1)

    /// A sharp streak of light falls from top to bottom, clipped to the drop's silhouette —
    /// like a spark dropping straight down a wire. It only takes the first `fallWindow`
    /// fraction of the burst (fast, not a slow glide); the icon then sits still for the rest
    /// of the burst. The drop shape itself never moves — the earlier squash-stretch "slosh"
    /// wobble was too small a pixel delta at menu bar size (±10% width / ±7% height, well
    /// under 2px) to reliably read as motion, and a first attempt at this shine swept
    /// sideways across the full burst, which read as slow drifting rather than a fall.
    static func image(phase: CGFloat, size: CGFloat) -> NSImage? {
        guard size.isFinite, size > 0 else {
            return nil
        }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.shouldAntialias = true

        let canvas = NSRect(x: 0, y: 0, width: size, height: size)
        let availableHeight = size * (1 - 0.24)
        let availableWidth = availableHeight * WaterDropletOutline.aspectRatio
        let rect = NSRect(
            x: canvas.midX - availableWidth / 2,
            y: canvas.midY - availableHeight / 2,
            width: availableWidth,
            height: availableHeight
        )

        let path = outline(in: rect)
        keyColor.setFill()
        path.fill()

        if let shine = fallingShineBand(phase: phase, size: size) {
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            NSColor.white.withAlphaComponent(0.95).setFill()
            shine.fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        image.isTemplate = false
        return image
    }

    /// A thin band translated along its own length (not swept sideways across it), from
    /// fully above the icon to fully below, only during the first `fallWindow` of the burst
    /// — `nil` afterward, so nothing draws for the remainder. Clipped to the drop's
    /// silhouette by the caller so only the portion crossing the shape is visible.
    private static func fallingShineBand(phase: CGFloat, size: CGFloat) -> NSBezierPath? {
        let fallWindow: CGFloat = 0.28
        guard phase <= fallWindow else {
            return nil
        }
        let fallT = phase / fallWindow

        let tilt: CGFloat = 20 * .pi / 180 // slight lean off vertical, not a dead-straight drop
        let along = CGPoint(x: -sin(tilt), y: -cos(tilt)) // points downward (AppKit is y-up)
        let across = CGPoint(x: -along.y, y: along.x)

        let center = CGPoint(x: size / 2, y: size / 2)
        let travel = size * 2.2
        let offset = -travel / 2 + travel * fallT
        let bandCenter = CGPoint(x: center.x + along.x * offset, y: center.y + along.y * offset)

        let halfLength = size * 0.55
        let halfWidth = size * 0.06 // thin — sharp, not a soft wide glow

        func corner(_ lengthSign: CGFloat, _ widthSign: CGFloat) -> NSPoint {
            NSPoint(
                x: bandCenter.x + along.x * halfLength * lengthSign + across.x * halfWidth * widthSign,
                y: bandCenter.y + along.y * halfLength * lengthSign + across.y * halfWidth * widthSign
            )
        }

        let path = NSBezierPath()
        path.move(to: corner(1, 1))
        path.line(to: corner(1, -1))
        path.line(to: corner(-1, -1))
        path.line(to: corner(-1, 1))
        path.close()
        return path
    }

    private static func outline(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()

        func point(_ fraction: CGPoint) -> NSPoint {
            NSPoint(
                x: rect.minX + rect.width * fraction.x,
                y: rect.minY + rect.height * (1 - fraction.y)
            )
        }

        path.move(to: point(WaterDropletOutline.start))
        for segment in WaterDropletOutline.segments {
            if let control1 = segment.control1, let control2 = segment.control2 {
                path.curve(to: point(segment.end), controlPoint1: point(control1), controlPoint2: point(control2))
            } else {
                path.line(to: point(segment.end))
            }
        }
        path.close()

        return path
    }
}
