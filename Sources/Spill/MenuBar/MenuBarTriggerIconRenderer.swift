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
            let path = centerline(in: rect)
            path.lineWidth = max(2.0, size * 0.18)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            tintColor.setStroke()
            path.stroke()

            image.isTemplate = false
            return image
        }

        private static func centerline(in rect: NSRect) -> NSBezierPath {
            let path = NSBezierPath()

            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(
                    x: rect.minX + rect.width * x,
                    y: rect.minY + rect.height * (1 - y)
                )
            }

            path.move(to: point(0.76, 0.16))
            path.curve(
                to: point(0.34, 0.22),
                controlPoint1: point(0.62, 0.10),
                controlPoint2: point(0.42, 0.10)
            )
            path.curve(
                to: point(0.27, 0.42),
                controlPoint1: point(0.24, 0.32),
                controlPoint2: point(0.21, 0.38)
            )
            path.curve(
                to: point(0.60, 0.51),
                controlPoint1: point(0.34, 0.49),
                controlPoint2: point(0.51, 0.48)
            )
            path.curve(
                to: point(0.72, 0.70),
                controlPoint1: point(0.72, 0.55),
                controlPoint2: point(0.80, 0.62)
            )
            path.curve(
                to: point(0.25, 0.84),
                controlPoint1: point(0.62, 0.86),
                controlPoint2: point(0.42, 0.90)
            )

            return path
        }
    }
}
