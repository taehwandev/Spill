import AppKit

extension MenuBarItemSnapshot {
    var iconImage: NSImage? {
        guard let imageData else {
            return nil
        }

        return MenuBarIconImageCache.shared.image(for: imageData)
    }
}
