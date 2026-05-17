import AppKit

struct MenuBarItemImageProvider {
    private static let iconPixelSize = 64
    private static let iconPointSize: CGFloat = 32

    func imageData(bundleIdentifier: String?, processIdentifier: pid_t) -> Data? {
        guard let image = appIcon(bundleIdentifier: bundleIdentifier, processIdentifier: processIdentifier) else {
            return nil
        }

        return downsampledPNGData(from: image)
    }

    private func appIcon(bundleIdentifier: String?, processIdentifier: pid_t) -> NSImage? {
        if let bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        {
            return NSWorkspace.shared.icon(forFile: url.path)
        }

        return NSRunningApplication(processIdentifier: processIdentifier)?.icon
    }

    private func downsampledPNGData(from image: NSImage) -> Data? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Self.iconPixelSize,
            pixelsHigh: Self.iconPixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        let pointSize = NSSize(width: Self.iconPointSize, height: Self.iconPointSize)
        bitmap.size = pointSize

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: pointSize),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [.compressionFactor: 0.82])
    }
}
