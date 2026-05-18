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
        let tailSpeed = 1.15 + load * 1.25
        let tailWag = sin(angle * tailSpeed) * (1.3 + load * 1.15)
        let tailCurl = cos(angle * tailSpeed) * (0.28 + load * 0.22)
        let bodyRect = CGRect(x: rect.minX + 3.4, y: rect.minY + 3.1, width: 6.4, height: 4.2)
        let headRect = CGRect(x: rect.minX + 1.7, y: rect.minY + 5.2, width: 4.4, height: 3.8)
        let catPath = CGMutablePath()

        catPath.addEllipse(in: bodyRect)
        catPath.addRoundedRect(in: headRect, cornerWidth: 2.3, cornerHeight: 2.3)
        catPath.move(to: CGPoint(x: headRect.minX + 0.45, y: headRect.maxY - 0.9))
        catPath.addLine(to: CGPoint(x: headRect.minX + 1.15, y: rect.maxY - 1.0))
        catPath.addLine(to: CGPoint(x: headRect.minX + 2.0, y: headRect.maxY - 0.35))
        catPath.closeSubpath()
        catPath.move(to: CGPoint(x: headRect.maxX - 2.0, y: headRect.maxY - 0.35))
        catPath.addLine(to: CGPoint(x: headRect.maxX - 1.0, y: rect.maxY - 1.1))
        catPath.addLine(to: CGPoint(x: headRect.maxX - 0.35, y: headRect.maxY - 1.0))
        catPath.closeSubpath()

        context.saveGState()
        context.setStrokeColor(tintColor.cgColor)
        context.setLineWidth(1.55)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let tailPath = CGMutablePath()
        let tailStartX = bodyRect.maxX - 0.4
        let tailStartY = bodyRect.midY + 0.2
        let tailEnd = CGPoint(
            x: rect.maxX - 1.15 - abs(tailWag) * 0.10,
            y: rect.minY + 8.0 + tailWag
        )
        tailPath.move(to: CGPoint(x: tailStartX, y: tailStartY))
        tailPath.addCurve(
            to: tailEnd,
            control1: CGPoint(x: rect.maxX - 2.4, y: rect.minY + 4.7),
            control2: CGPoint(x: rect.maxX - 0.6 + tailCurl, y: rect.minY + 6.3 + tailWag * 0.55)
        )
        context.addPath(tailPath)
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -0.45),
            blur: 0.9,
            color: tintColor.withAlphaComponent(0.26).cgColor
        )
        context.setFillColor(tintColor.cgColor)
        context.addPath(catPath)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.setFillColor(NSColor.controlBackgroundColor.withAlphaComponent(0.82).cgColor)
        context.fillEllipse(in: CGRect(x: headRect.minX + 1.15, y: headRect.minY + 1.9, width: 0.85, height: 0.85))
        context.restoreGState()
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
