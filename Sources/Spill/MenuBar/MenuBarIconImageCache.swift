import AppKit
import ImageIO

final class MenuBarIconImageCache: @unchecked Sendable {
    static let shared = MenuBarIconImageCache()

    private static let maximumPixelSize = 64
    private static let pointSize = NSSize(width: 32, height: 32)

    private let cache = NSCache<NSData, NSImage>()

    private init() {
        cache.countLimit = 160
        cache.totalCostLimit = 8 * 1_024 * 1_024
    }

    func image(for data: Data) -> NSImage? {
        let key = data as NSData
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        guard !Thread.isMainThread else {
            return nil
        }

        guard let decodedImage = Self.decodedImage(from: data) else {
            return nil
        }

        let image = NSImage(cgImage: decodedImage, size: Self.pointSize(for: decodedImage))
        cache.setObject(image, forKey: key, cost: max(data.count, decodedImage.bytesPerRow * decodedImage.height))
        return image
    }

    @discardableResult
    func prepareImage(for data: Data) -> Bool {
        image(for: data) != nil
    }

    func removeAllObjects() {
        cache.removeAllObjects()
    }

    private static func decodedImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return decodedSRGBImage(from: image)
    }

    private static func decodedSRGBImage(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            return nil
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }

    private static func pointSize(for image: CGImage) -> NSSize {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let largestDimension = max(width, height)
        guard largestDimension > Self.pointSize.width else {
            return NSSize(width: width, height: height)
        }

        let scale = largestDimension / Self.pointSize.width
        return NSSize(width: width / scale, height: height / scale)
    }
}
