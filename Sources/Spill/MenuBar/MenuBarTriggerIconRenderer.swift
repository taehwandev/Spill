import AppKit

@MainActor
enum MenuBarTriggerIconRenderer {
    static func image(
        style: MenuBarTriggerIconStyle,
        phase: CGFloat = 0,
        size: CGFloat = 13
    ) -> NSImage? {
        switch style {
        case .spill:
            return MenuBarTriggerIconDropletRenderer.image(phase: phase, size: size)
        case .symbolizedS:
            return MenuBarTriggerIconSymbolizedSRenderer.image(phase: phase, size: size)
        }
    }
}
