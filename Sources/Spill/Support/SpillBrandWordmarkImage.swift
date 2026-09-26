import AppKit
import ImageIO

/// The wordmark asset is 3212×1588 px, about 20 MB once decoded, but lockups draw it at most
/// ~25 pt tall. Decode it once, downsampled to a size that stays sharp at 3x.
@MainActor
enum SpillBrandWordmarkImage {
    static let maximumPixelSize = 512

    static let shared: NSImage? = {
        guard let url = SpillResourceBundle.resourceBundle()?.url(forResource: "spill-logo-wordmark", withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceShouldCacheImmediately: true,
                  kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
              ] as CFDictionary)
        else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }()
}
