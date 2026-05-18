import AppKit

@MainActor
enum MenuBarTriggerIconRenderer {
    static func image(
        style: MenuBarTriggerIconStyle,
        tintColor: NSColor,
        usageRatio: Double,
        phase: CGFloat = 0,
        size: CGFloat = 13
    ) -> NSImage? {
        nil
    }
}
