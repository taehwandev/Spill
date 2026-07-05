import AppKit

@MainActor
enum MenuBarSymbolImageCache {
    private struct Key: Hashable {
        let symbolName: String
        let accessibilityDescription: String?
        let pointSize: Double
        let weight: Double
    }

    private static var images: [Key: NSImage] = [:]

    static func configuration(
        pointSize: CGFloat,
        weight: NSFont.Weight = .semibold
    ) -> NSImage.SymbolConfiguration {
        NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    }

    static func image(
        named symbolName: String,
        accessibilityDescription: String?,
        pointSize: CGFloat,
        weight: NSFont.Weight = .semibold
    ) -> NSImage? {
        let key = Key(
            symbolName: symbolName,
            accessibilityDescription: accessibilityDescription,
            pointSize: Double(pointSize),
            weight: Double(weight.rawValue)
        )
        if let cached = images[key] {
            return cached
        }

        let config = configuration(pointSize: pointSize, weight: weight)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        if let image {
            images[key] = image
        }
        return image
    }
}
