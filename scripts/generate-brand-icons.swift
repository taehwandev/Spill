import AppKit
import CoreGraphics
import Foundation

private func drawBackground(in context: CGContext, isAI: Bool) {
    let bgColors = [
        NSColor(red: 0.14, green: 0.15, blue: 0.17, alpha: 1.0).cgColor,
        NSColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 1.0).cgColor
    ] as CFArray
    let bgGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: bgColors,
        locations: [0.0, 1.0]
    )!
    context.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: 512, y: 924),
        end: CGPoint(x: 512, y: 100),
        options: []
    )

    let sheenColors = [
        NSColor.white.withAlphaComponent(0.08).cgColor,
        NSColor.clear.cgColor
    ] as CFArray
    let sheenGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: sheenColors,
        locations: [0.0, 1.0]
    )!
    context.drawRadialGradient(
        sheenGradient,
        startCenter: CGPoint(x: 512, y: 900),
        startRadius: 0,
        endCenter: CGPoint(x: 512, y: 512),
        endRadius: 600,
        options: []
    )

    let auraColor = isAI
        ? NSColor(red: 0.09, green: 0.75, blue: 0.65, alpha: 0.22).cgColor
        : NSColor(red: 0.09, green: 0.75, blue: 0.55, alpha: 0.20).cgColor
    let auraColors = [auraColor, NSColor.clear.cgColor] as CFArray
    let auraGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: auraColors,
        locations: [0.0, 1.0]
    )!
    let auraCenter = CGPoint(x: isAI ? 470 : 512, y: 480)
    context.drawRadialGradient(
        auraGradient,
        startCenter: auraCenter,
        startRadius: 40,
        endCenter: auraCenter,
        endRadius: 360,
        options: []
    )
}

private func drawDroplet(in context: CGContext, isAI: Bool) {
    let height: CGFloat = isAI ? 460 : 490
    let width = height * (660.0 / 866.0)
    let centerX: CGFloat = isAI ? 450 : 512
    let centerY: CGFloat = isAI ? 530 : 500
    let origin = CGPoint(x: centerX - width / 2, y: centerY - height / 2)

    func point(_ value: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + value.x * width, y: origin.y + (1.0 - value.y) * height)
    }

    let path = CGMutablePath()
    path.move(to: point(CGPoint(x: 0.5000, y: 0.0000)))
    path.addLine(to: point(CGPoint(x: 0.8212, y: 0.4088)))
    path.addCurve(
        to: point(CGPoint(x: 0.8788, y: 0.8730)),
        control1: point(CGPoint(x: 0.9545, y: 0.5796)),
        control2: point(CGPoint(x: 1.0000, y: 0.7529))
    )
    path.addCurve(
        to: point(CGPoint(x: 0.5000, y: 1.0000)),
        control1: point(CGPoint(x: 0.7894, y: 0.9619)),
        control2: point(CGPoint(x: 0.6485, y: 1.0000))
    )
    path.addCurve(
        to: point(CGPoint(x: 0.1212, y: 0.8730)),
        control1: point(CGPoint(x: 0.3515, y: 1.0000)),
        control2: point(CGPoint(x: 0.2106, y: 0.9619))
    )
    path.addCurve(
        to: point(CGPoint(x: 0.1788, y: 0.4088)),
        control1: point(CGPoint(x: 0.0000, y: 0.7529)),
        control2: point(CGPoint(x: 0.0455, y: 0.5796))
    )
    path.closeSubpath()

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -18),
        blur: 30,
        color: NSColor(red: 0.05, green: 0.4, blue: 0.3, alpha: 0.50).cgColor
    )
    let dropColors = [
        NSColor(red: 0.11, green: 0.82, blue: 0.60, alpha: 1.0).cgColor,
        NSColor(red: 0.06, green: 0.65, blue: 0.48, alpha: 1.0).cgColor
    ] as CFArray
    let dropGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: dropColors,
        locations: [0.0, 1.0]
    )!
    context.addPath(path)
    context.clip()
    context.drawLinearGradient(
        dropGradient,
        start: CGPoint(x: centerX, y: origin.y + height),
        end: CGPoint(x: centerX, y: origin.y),
        options: []
    )

    let highlightColors = [
        NSColor.white.withAlphaComponent(0.40).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor
    ] as CFArray
    let highlightGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: highlightColors,
        locations: [0.0, 1.0]
    )!
    context.drawLinearGradient(
        highlightGradient,
        start: CGPoint(x: centerX, y: origin.y + height),
        end: CGPoint(x: centerX, y: origin.y + height * 0.45),
        options: []
    )
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.setLineWidth(1.5)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor)
    context.strokePath()
    context.restoreGState()
}

private func drawAISparkle(in context: CGContext) {
    let configuration = NSImage.SymbolConfiguration(pointSize: 250, weight: .bold)
    guard let sparkle = NSImage(
        systemSymbolName: "sparkles",
        accessibilityDescription: nil
    )?.withSymbolConfiguration(configuration) else { return }

    let rect = NSRect(x: 520, y: 150, width: 330, height: 330)
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -6),
        blur: 24,
        color: NSColor.black.withAlphaComponent(0.6).cgColor
    )
    let tinted = NSImage(size: rect.size, flipped: false) { destination in
        guard let graphicsContext = NSGraphicsContext.current?.cgContext else { return false }
        sparkle.draw(in: destination)
        graphicsContext.setBlendMode(.sourceIn)
        let colors = [
            NSColor(red: 0.45, green: 0.95, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(red: 0.12, green: 0.82, blue: 0.68, alpha: 1.0).cgColor
        ] as CFArray
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0.0, 1.0]
        )!
        graphicsContext.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: destination.height),
            end: CGPoint(x: destination.width, y: 0),
            options: []
        )
        return true
    }
    tinted.draw(in: rect)
    context.restoreGState()
}

private func createIcon(isAI: Bool, outputPath: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 1024,
        pixelsHigh: 1024,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
        fputs("Failed to create graphics context\n", stderr)
        exit(1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    graphicsContext.imageInterpolation = .high
    let context = graphicsContext.cgContext
    let squircle = CGPath(
        roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
        cornerWidth: 185,
        cornerHeight: 185,
        transform: nil
    )

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -24),
        blur: 38,
        color: NSColor.black.withAlphaComponent(0.40).cgColor
    )
    context.addPath(squircle)
    context.setFillColor(NSColor(white: 0.12, alpha: 1.0).cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(squircle)
    context.clip()
    drawBackground(in: context, isAI: isAI)
    drawDroplet(in: context, isAI: isAI)
    if isAI { drawAISparkle(in: context) }
    context.addPath(squircle)
    context.setLineWidth(2.0)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
    context.strokePath()
    context.restoreGState()
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        fputs("Failed to generate PNG representation\n", stderr)
        exit(1)
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Generated icon: \(outputPath)")
    } catch {
        fputs("Failed to write icon: \(error)\n", stderr)
        exit(1)
    }
}

let rootDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
createIcon(isAI: false, outputPath: rootDir.appendingPathComponent("docs/assets/spill-icon.png").path)
createIcon(isAI: true, outputPath: rootDir.appendingPathComponent("docs/assets/spill-ai-icon.png").path)
