import AppKit

@MainActor
enum MenuBarTriggerIconRenderer {
    static func image(
        style: MenuBarTriggerIconStyle,
        tintColor: NSColor,
        usageRatio: Double,
        phase: CGFloat = 0,
        size: CGFloat = 13
    ) -> NSImage? {
        switch style {
        case .spill:
            return nil
        case .symbolizedS:
            return SymbolizedSRenderer.image(tintColor: tintColor, size: size)
        }
    }

    private enum SymbolizedSRenderer {
        static func image(tintColor: NSColor, size: CGFloat) -> NSImage? {
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
            tintColor.setFill()
            path.fill()

            image.isTemplate = false
            return image
        }

        /// The Spill wordmark's "S" glyph outline (`WordmarkSShape.points`), filled rather
        /// than stroked so the menu bar glyph matches the brand mark used everywhere else
        /// (web favicon, Settings brand lockup) instead of a simplified centerline curve.
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
}
