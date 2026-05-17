import AppKit

final class MenuBarIconImageCache: @unchecked Sendable {
    static let shared = MenuBarIconImageCache()

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

        guard let image = NSImage(data: data) else {
            return nil
        }

        cache.setObject(image, forKey: key, cost: data.count)
        return image
    }
}
