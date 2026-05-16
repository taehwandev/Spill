import AppKit
import Foundation

struct IconImage {
    let name: String
    let pixels: Int
}

let images = [
    IconImage(name: "icon_16x16.png", pixels: 16),
    IconImage(name: "icon_16x16@2x.png", pixels: 32),
    IconImage(name: "icon_32x32.png", pixels: 32),
    IconImage(name: "icon_32x32@2x.png", pixels: 64),
    IconImage(name: "icon_128x128.png", pixels: 128),
    IconImage(name: "icon_128x128@2x.png", pixels: 256),
    IconImage(name: "icon_256x256.png", pixels: 256),
    IconImage(name: "icon_256x256@2x.png", pixels: 512),
    IconImage(name: "icon_512x512.png", pixels: 512),
    IconImage(name: "icon_512x512@2x.png", pixels: 1024)
]

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-app-icon.swift <output.iconset>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default

if fileManager.fileExists(atPath: outputURL.path) {
    try fileManager.removeItem(at: outputURL)
}

try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

for image in images {
    let data = try renderIcon(pixels: image.pixels)
    try data.write(to: outputURL.appendingPathComponent(image.name), options: .atomic)
}

func renderIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconError.bitmapCreationFailed
    }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconError.contextCreationFailed
    }

    NSGraphicsContext.current = graphicsContext

    let context = graphicsContext.cgContext
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let rect = CGRect(x: 0, y: 0, width: pixels, height: pixels)
    drawBackground(in: rect, context: context)
    drawSpillMark(in: rect, context: context)

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconError.pngEncodingFailed
    }

    return data
}

func drawBackground(in rect: CGRect, context: CGContext) {
    let inset = rect.width * 0.035
    let backgroundRect = rect.insetBy(dx: inset, dy: inset)
    let cornerRadius = rect.width * 0.225
    let path = CGPath(
        roundedRect: backgroundRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    context.saveGState()
    context.addPath(path)
    context.clip()

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.115, green: 0.135, blue: 0.15, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.035, green: 0.042, blue: 0.052, alpha: 1).cgColor
        ] as CFArray,
        locations: [0, 1]
    )

    if let gradient {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: backgroundRect.midX, y: backgroundRect.maxY),
            end: CGPoint(x: backgroundRect.midX, y: backgroundRect.minY),
            options: []
        )
    }

    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.05, green: 0.82, blue: 0.76, alpha: 0.16).cgColor,
            NSColor(calibratedRed: 0.05, green: 0.82, blue: 0.76, alpha: 0).cgColor
        ] as CFArray,
        locations: [0, 1]
    )

    if let glow {
        context.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: rect.midX, y: rect.height * 0.42),
            startRadius: 0,
            endCenter: CGPoint(x: rect.midX, y: rect.height * 0.42),
            endRadius: rect.width * 0.46,
            options: []
        )
    }

    context.restoreGState()

    context.setStrokeColor(NSColor.white.withAlphaComponent(0.16).cgColor)
    context.setLineWidth(max(1, rect.width * 0.01))
    context.addPath(path)
    context.strokePath()

    context.setStrokeColor(NSColor.black.withAlphaComponent(0.42).cgColor)
    context.setLineWidth(max(1, rect.width * 0.006))
    context.addPath(path)
    context.strokePath()
}

func drawSpillMark(in rect: CGRect, context: CGContext) {
    let spillPath = spillPath(in: rect)

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -rect.height * 0.01),
        blur: rect.width * 0.055,
        color: NSColor(calibratedRed: 0.08, green: 0.95, blue: 0.85, alpha: 0.55).cgColor
    )

    context.setFillColor(NSColor(calibratedRed: 0.06, green: 0.84, blue: 0.78, alpha: 0.95).cgColor)
    context.addPath(spillPath)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(spillPath)
    context.clip()

    let markGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.60, green: 1.0, blue: 0.95, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.10, green: 0.84, blue: 0.78, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.03, green: 0.50, blue: 0.54, alpha: 1).cgColor
        ] as CFArray,
        locations: [0, 0.48, 1]
    )

    if let markGradient {
        context.drawLinearGradient(
            markGradient,
            start: CGPoint(x: rect.width * 0.34, y: rect.height * 0.67),
            end: CGPoint(x: rect.width * 0.70, y: rect.height * 0.28),
            options: []
        )
    }

    context.restoreGState()

    context.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor)
    context.setLineWidth(max(1, rect.width * 0.007))
    context.addPath(spillPath)
    context.strokePath()
}

func spillPath(in rect: CGRect) -> CGPath {
    let width = rect.width
    let height = rect.height
    let path = CGMutablePath()

    path.move(to: CGPoint(x: width * 0.22, y: height * 0.43))
    path.addCurve(
        to: CGPoint(x: width * 0.39, y: height * 0.56),
        control1: CGPoint(x: width * 0.22, y: height * 0.52),
        control2: CGPoint(x: width * 0.30, y: height * 0.58)
    )
    path.addCurve(
        to: CGPoint(x: width * 0.54, y: height * 0.51),
        control1: CGPoint(x: width * 0.45, y: height * 0.55),
        control2: CGPoint(x: width * 0.48, y: height * 0.50)
    )
    path.addCurve(
        to: CGPoint(x: width * 0.80, y: height * 0.47),
        control1: CGPoint(x: width * 0.64, y: height * 0.55),
        control2: CGPoint(x: width * 0.79, y: height * 0.57)
    )
    path.addCurve(
        to: CGPoint(x: width * 0.65, y: height * 0.31),
        control1: CGPoint(x: width * 0.81, y: height * 0.36),
        control2: CGPoint(x: width * 0.74, y: height * 0.31)
    )
    path.addLine(to: CGPoint(x: width * 0.34, y: height * 0.31))
    path.addCurve(
        to: CGPoint(x: width * 0.22, y: height * 0.43),
        control1: CGPoint(x: width * 0.25, y: height * 0.31),
        control2: CGPoint(x: width * 0.21, y: height * 0.36)
    )
    path.closeSubpath()

    return path
}

enum IconError: Error {
    case bitmapCreationFailed
    case contextCreationFailed
    case pngEncodingFailed
}
