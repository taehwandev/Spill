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
        case .cat:
            return drawnImage(size: size) { rect, context in
                drawCat(
                    in: rect,
                    context: context,
                    tintColor: tintColor,
                    usageRatio: usageRatio,
                    phase: phase
                )
            }
        case .liquid:
            return drawnImage(size: size) { rect, context in
                drawLiquid(
                    in: rect,
                    context: context,
                    tintColor: tintColor,
                    usageRatio: usageRatio,
                    phase: phase
                )
            }
        }
    }

    private static func drawnImage(
        size: CGFloat,
        drawingHandler: @escaping (CGRect, CGContext) -> Void
    ) -> NSImage {
        let baseCanvasSize: CGFloat = 13
        let canvasSize = max(size, 1)
        let imageSize = NSSize(width: canvasSize, height: canvasSize)
        return NSImage(size: imageSize, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }

            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.scaleBy(x: rect.width / baseCanvasSize, y: rect.height / baseCanvasSize)
            drawingHandler(CGRect(x: 0, y: 0, width: baseCanvasSize, height: baseCanvasSize), context)
            return true
        }
    }

    private static func drawCat(
        in rect: CGRect,
        context: CGContext,
        tintColor: NSColor,
        usageRatio: Double,
        phase: CGFloat
    ) {
        let load = CGFloat(usageRatio.clamped(to: 0...1))
        let angle = phase * .pi * 2
        let bob = sin(angle) * (0.25 + load * 0.5)
        let tailWag = sin(angle * 1.8) * (0.7 + load * 0.8)
        let bodyRect = rect.insetBy(dx: 2.2, dy: 3.3).offsetBy(dx: 0, dy: bob - load * 0.3)
        let headRect = rect.insetBy(dx: 2.4, dy: 2.7).offsetBy(dx: 0, dy: bob)
        let headPath = CGPath(
            roundedRect: headRect,
            cornerWidth: 3.2,
            cornerHeight: 3.2,
            transform: nil
        )
        let path = CGMutablePath()
        path.addEllipse(in: bodyRect.insetBy(dx: 0.6, dy: 1.4))
        path.move(to: CGPoint(x: rect.minX + 2.7, y: rect.minY + 8.2 + bob))
        path.addLine(to: CGPoint(x: rect.minX + 3.8, y: rect.minY + 11.4 + bob))
        path.addLine(to: CGPoint(x: rect.minX + 6.0, y: rect.minY + 8.8 + bob))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.maxX - 6.0, y: rect.minY + 8.8 + bob))
        path.addLine(to: CGPoint(x: rect.maxX - 3.8, y: rect.minY + 11.4 + bob))
        path.addLine(to: CGPoint(x: rect.maxX - 2.7, y: rect.minY + 8.2 + bob))
        path.closeSubpath()
        path.addPath(headPath)

        context.saveGState()
        context.setStrokeColor(tintColor.withAlphaComponent(0.92).cgColor)
        context.setLineWidth(1.25)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: bodyRect.maxX - 0.4, y: bodyRect.midY + 0.2))
        context.addCurve(
            to: CGPoint(x: rect.maxX - 1.1, y: rect.minY + 8.2 + tailWag),
            control1: CGPoint(x: rect.maxX - 1.7, y: rect.minY + 4.6 + bob),
            control2: CGPoint(x: rect.maxX - 1.1, y: rect.minY + 6.5 + tailWag)
        )
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -0.6), blur: 1.0, color: tintColor.withAlphaComponent(0.32).cgColor)
        context.setFillColor(tintColor.cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        let eyeColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        context.setFillColor(eyeColor)
        context.fillEllipse(in: CGRect(x: rect.minX + 4.7, y: rect.minY + 6.4 + bob, width: 1.0, height: 1.0))
        context.fillEllipse(in: CGRect(x: rect.maxX - 5.7, y: rect.minY + 6.4 + bob, width: 1.0, height: 1.0))
    }

    private static func drawLiquid(
        in rect: CGRect,
        context: CGContext,
        tintColor: NSColor,
        usageRatio: Double,
        phase: CGFloat
    ) {
        let clampedRatio = usageRatio.clamped(to: 0...1)
        let load = CGFloat(clampedRatio)
        let angle = phase * .pi * 2
        let pulse = sin(angle)
        let slosh = cos(angle * 0.85)
        let motion = 0.35 + load * 0.85
        let bodyRect = rect
            .insetBy(dx: 0.8 + clampedRatio * 0.35 - abs(pulse) * 0.16, dy: 1.1 - clampedRatio * 0.35)
            .offsetBy(dx: slosh * motion * 0.45, dy: pulse * motion * 0.22)
        let path = spillPath(in: bodyRect)

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -0.6),
            blur: 1.2 + clampedRatio * 1.2,
            color: tintColor.withAlphaComponent(0.28 + clampedRatio * 0.22).cgColor
        )
        context.setFillColor(tintColor.withAlphaComponent(0.96).cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.18 + clampedRatio * 0.28).cgColor)
        context.setLineWidth(1.0)
        let waveY = bodyRect.minY + bodyRect.height * (0.40 + clampedRatio * 0.18) + pulse * motion * 0.8
        context.move(to: CGPoint(x: bodyRect.minX + bodyRect.width * 0.18, y: waveY))
        context.addCurve(
            to: CGPoint(x: bodyRect.maxX - bodyRect.width * 0.12, y: waveY - clampedRatio * 0.7),
            control1: CGPoint(x: bodyRect.minX + bodyRect.width * 0.36, y: waveY + 1.2 + slosh * 0.5),
            control2: CGPoint(x: bodyRect.minX + bodyRect.width * 0.60, y: waveY - 1.2 - slosh * 0.5)
        )
        context.strokePath()

        context.setFillColor(NSColor.white.withAlphaComponent(0.20 + clampedRatio * 0.18).cgColor)
        context.fillEllipse(
            in: CGRect(
                x: bodyRect.minX + bodyRect.width * (0.30 + slosh * 0.05),
                y: bodyRect.minY + bodyRect.height * 0.47 + pulse * 0.4,
                width: 1.2,
                height: 1.2
            )
        )
        context.restoreGState()
    }

    private static func spillPath(in rect: CGRect) -> CGPath {
        let width = rect.width
        let height = rect.height
        let x = rect.minX
        let y = rect.minY
        let path = CGMutablePath()

        path.move(to: CGPoint(x: x + width * 0.22, y: y + height * 0.43))
        path.addCurve(
            to: CGPoint(x: x + width * 0.39, y: y + height * 0.56),
            control1: CGPoint(x: x + width * 0.22, y: y + height * 0.52),
            control2: CGPoint(x: x + width * 0.30, y: y + height * 0.58)
        )
        path.addCurve(
            to: CGPoint(x: x + width * 0.54, y: y + height * 0.51),
            control1: CGPoint(x: x + width * 0.45, y: y + height * 0.55),
            control2: CGPoint(x: x + width * 0.48, y: y + height * 0.50)
        )
        path.addCurve(
            to: CGPoint(x: x + width * 0.80, y: y + height * 0.47),
            control1: CGPoint(x: x + width * 0.64, y: y + height * 0.55),
            control2: CGPoint(x: x + width * 0.79, y: y + height * 0.57)
        )
        path.addCurve(
            to: CGPoint(x: x + width * 0.65, y: y + height * 0.31),
            control1: CGPoint(x: x + width * 0.81, y: y + height * 0.36),
            control2: CGPoint(x: x + width * 0.74, y: y + height * 0.31)
        )
        path.addLine(to: CGPoint(x: x + width * 0.34, y: y + height * 0.31))
        path.addCurve(
            to: CGPoint(x: x + width * 0.22, y: y + height * 0.43),
            control1: CGPoint(x: x + width * 0.25, y: y + height * 0.31),
            control2: CGPoint(x: x + width * 0.21, y: y + height * 0.36)
        )
        path.closeSubpath()

        return path
    }
}
