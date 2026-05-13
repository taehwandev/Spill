import AppKit

struct MenuBarItemImageProvider {
    func imageData(bundleIdentifier: String?, processIdentifier: pid_t) -> Data? {
        guard let image = appIcon(bundleIdentifier: bundleIdentifier, processIdentifier: processIdentifier),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    private func appIcon(bundleIdentifier: String?, processIdentifier: pid_t) -> NSImage? {
        if let bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        {
            return NSWorkspace.shared.icon(forFile: url.path)
        }

        return NSRunningApplication(processIdentifier: processIdentifier)?.icon
    }
}
