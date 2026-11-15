import AppKit

/// Drawing helpers for the menu bar characters. Characters are described in
/// a unit square with y pointing down (like the droplet outline data); this
/// maps that space onto the AppKit image, whose y points up, and scales line
/// widths with the icon so a character reads the same at every size.
///
/// Characters are template glyphs: only alpha matters, so everything is drawn
/// in black and AppKit tints it to the menu bar (white on dark, black on
/// light), exactly like the SF Symbols beside it.
@MainActor
struct CharacterCanvas {
    let size: CGFloat

    func point(_ unit: CGPoint) -> NSPoint {
        NSPoint(x: unit.x * size, y: (1 - unit.y) * size)
    }

    /// An ellipse wound clockwise on screen, the same way `polygon` winds,
    /// so overlapping parts merge under the non-zero rule instead of
    /// cancelling into holes.
    func oval(center: CGPoint, rx: CGFloat, ry: CGFloat) -> NSBezierPath {
        let k: CGFloat = 0.55228475
        let p = { (dx: CGFloat, dy: CGFloat) -> NSPoint in
            self.point(CGPoint(x: center.x + dx, y: center.y + dy))
        }
        let path = NSBezierPath()
        path.move(to: p(0, -ry))
        path.curve(to: p(rx, 0), controlPoint1: p(k * rx, -ry), controlPoint2: p(rx, -k * ry))
        path.curve(to: p(0, ry), controlPoint1: p(rx, k * ry), controlPoint2: p(k * rx, ry))
        path.curve(to: p(-rx, 0), controlPoint1: p(-k * rx, ry), controlPoint2: p(-rx, k * ry))
        path.curve(to: p(0, -ry), controlPoint1: p(-rx, -k * ry), controlPoint2: p(-k * rx, -ry))
        path.close()
        return path
    }

    /// A closed polygon, re-ordered when needed so it winds like `oval`.
    func polygon(_ unordered: [CGPoint]) -> NSBezierPath {
        let signedArea = zip(unordered, unordered.dropFirst() + unordered.prefix(1))
            .reduce(0) { $0 + $1.0.x * $1.1.y - $1.1.x * $1.0.y }
        let points = signedArea < 0 ? Array(unordered.reversed()) : unordered
        let path = NSBezierPath()
        guard let first = points.first else { return path }
        path.move(to: point(first))
        for next in points.dropFirst() {
            path.line(to: point(next))
        }
        path.close()
        return path
    }

    /// Fills every part as one solid shape.
    func fillSilhouette(_ parts: [NSBezierPath]) {
        let silhouette = NSBezierPath()
        parts.forEach { silhouette.append($0) }
        silhouette.windingRule = .nonZero
        NSColor.black.setFill()
        silhouette.fill()
    }

    /// A round-capped line in glyph color, for tails.
    func strokeLimb(_ path: NSBezierPath, width: CGFloat) {
        NSColor.black.setStroke()
        path.lineWidth = width * size
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    /// Punches eyes out of the glyph so they show the menu bar behind it. A
    /// blink narrows each eye to a slit.
    func cutEyes(_ centers: [CGPoint], radius: CGFloat, blinking: Bool) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current?.compositingOperation = .clear
        for eye in centers {
            oval(center: eye, rx: radius * (blinking ? 1.2 : 1), ry: blinking ? radius * 0.3 : radius * 1.15).fill()
        }
    }
}

extension MenuBarTriggerIconCharacterRenderer {
    /// Rotates in the y-down unit space the characters are described in, so
    /// a positive angle turns clockwise on screen.
    static func rotate(_ point: CGPoint, around center: CGPoint, by angle: CGFloat) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return CGPoint(
            x: center.x + dx * cos(angle) - dy * sin(angle),
            y: center.y + dx * sin(angle) + dy * cos(angle)
        )
    }
}
