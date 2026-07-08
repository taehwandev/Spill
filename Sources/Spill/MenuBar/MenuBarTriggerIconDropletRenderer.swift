import AppKit

@MainActor
enum MenuBarTriggerIconDropletRenderer {
    private static let keyColor = NSColor(calibratedRed: 0.0863, green: 0.7451, blue: 0.5451, alpha: 1)

    /// A bright diagonal shine sweeps once across the drop, clipped to its silhouette — like
    /// light glinting off a wet surface. The drop shape itself stays still; the earlier
    /// squash-stretch "slosh" wobble was too small a pixel delta at menu bar size (±10%
    /// width / ±7% height, well under 2px) to reliably read as motion, so it's replaced
    /// entirely rather than layered under this.
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

        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSColor.white.withAlphaComponent(0.92).setFill()
        shineBand(phase: phase, size: size).fill()
        NSGraphicsContext.restoreGraphicsState()

        image.isTemplate = false
        return image
    }

    /// A wide diagonal band, translated perpendicular to its own length as `phase` advances
    /// from 0 to 1, so it enters from one side of the icon, sweeps across, and exits the
    /// other — clipped to the drop's silhouette by the caller so only the portion crossing
    /// the shape is visible.
    private static func shineBand(phase: CGFloat, size: CGFloat) -> NSBezierPath {
        let angle: CGFloat = .pi / 4 // 45°, bottom-left to top-right
        let along = CGPoint(x: cos(angle), y: sin(angle))
        let across = CGPoint(x: -sin(angle), y: cos(angle))

        let center = CGPoint(x: size / 2, y: size / 2)
        let travel = size * 1.4
        let offset = (phase - 0.5) * travel
        let bandCenter = CGPoint(x: center.x + across.x * offset, y: center.y + across.y * offset)

        let halfLength = size * 1.1 // long enough that both ends sit well outside the canvas
        let halfWidth = size * 0.11

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
