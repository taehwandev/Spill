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

do {
    guard CommandLine.arguments.count >= 2 else {
        fputs("Usage: generate-app-icon.swift <output.iconset> [source.png]\n", stderr)
        exit(2)
    }

    let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let fileManager = FileManager.default

    let sourceURL: URL
    if CommandLine.arguments.count >= 3 {
        sourceURL = URL(fileURLWithPath: CommandLine.arguments[2])
    } else {
        sourceURL = defaultSourceURL()
    }

    guard let sourceImage = NSImage(contentsOf: sourceURL) else {
        throw IconError.failedToLoadSourceImage(sourceURL.path)
    }

    if fileManager.fileExists(atPath: outputURL.path) {
        try fileManager.removeItem(at: outputURL)
    }

    try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

    for image in images {
        let data = try renderIcon(sourceImage: sourceImage, pixels: image.pixels)
        try data.write(to: outputURL.appendingPathComponent(image.name), options: .atomic)
    }
} catch {
    fputs("Error: \(errorMessage(error))\n", stderr)
    exit(1)
}

func defaultSourceURL() -> URL {
    // Fallback for direct script use; build-app.sh passes the repo asset path explicitly.
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("docs/assets/spill-icon.png")
}

func errorMessage(_ error: Error) -> String {
    if let iconError = error as? IconError {
        return iconError.description
    }
    return String(describing: error)
}

func renderIcon(sourceImage: NSImage, pixels: Int) throws -> Data {
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
    graphicsContext.imageInterpolation = .high

    let targetRect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.clear.setFill()
    targetRect.fill()

    let sourceRect = try centeredSquareCrop(for: sourceImage)
    sourceImage.draw(
        in: targetRect,
        from: sourceRect,
        operation: .copy,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconError.pngEncodingFailed
    }

    return data
}

func centeredSquareCrop(for image: NSImage) throws -> NSRect {
    let size = image.size
    guard size.width > 0, size.height > 0 else {
        throw IconError.sourceImageHasInvalidSize("width=\(size.width), height=\(size.height)")
    }

    let side = min(size.width, size.height)
    return NSRect(
        x: (size.width - side) * 0.5,
        y: (size.height - side) * 0.5,
        width: side,
        height: side
    )
}

enum IconError: Error, CustomStringConvertible {
    case bitmapCreationFailed
    case contextCreationFailed
    case pngEncodingFailed
    case failedToLoadSourceImage(String)
    case sourceImageHasInvalidSize(String)

    var description: String {
        switch self {
        case .bitmapCreationFailed: return "Failed to create bitmap representation"
        case .contextCreationFailed: return "Failed to create graphics context"
        case .pngEncodingFailed: return "Failed to encode image to PNG representation"
        case .failedToLoadSourceImage(let path): return "Failed to load source image from: \(path)"
        case .sourceImageHasInvalidSize(let details): return "Source image has invalid size: \(details)"
        }
    }
}
