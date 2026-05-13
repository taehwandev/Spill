import AppKit

extension MenuBarItemSnapshot {
    var iconImage: NSImage? {
        guard let imageData else {
            return nil
        }

        return NSImage(data: imageData)
    }
}
