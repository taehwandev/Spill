import AppKit

@MainActor
enum MenuBarTriggerIconSymbolizedSRenderer {
    private static let keyColor = NSColor(calibratedRed: 0.5137, green: 0.8353, blue: 0.7843, alpha: 1)

    /// Color fade in/out, not a directional wipe: the whole glyph fades between a faint base
    /// opacity and fully saturated color while staying legible at rest.
    static func image(phase: CGFloat, size: CGFloat) -> NSImage? {
        guard size.isFinite, size > 0 else {
            return nil
        }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.shouldAntialias = true

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
            .insetBy(dx: size * 0.12, dy: size * 0.12)
        let path = outline(in: rect)

        let baseAlpha: CGFloat = 0.28
        let fadeLevel: CGFloat
        if phase < 0.2 {
            let t = phase / 0.2
            fadeLevel = 1 - (1 - t) * (1 - t)
        } else {
            let t = (phase - 0.2) / 0.8
            fadeLevel = (1 - t) * (1 - t)
        }

        keyColor.withAlphaComponent(baseAlpha + (1 - baseAlpha) * fadeLevel).setFill()
        path.fill()

        image.isTemplate = false
        return image
    }

    private static func outline(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()

        func point(_ fraction: CGPoint) -> NSPoint {
            NSPoint(
                x: rect.minX + rect.width * fraction.x,
                y: rect.minY + rect.height * (1 - fraction.y)
            )
        }

        guard let first = WordmarkSShape.points.first else {
            return path
        }
        path.move(to: point(first))
        for fraction in WordmarkSShape.points.dropFirst() {
            path.line(to: point(fraction))
        }
        path.close()

        return path
    }
}
