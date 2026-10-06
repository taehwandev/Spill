import AppKit

@MainActor
enum MenuBarTriggerIconRenderer {
    private struct FrameKey: Hashable {
        let style: MenuBarTriggerIconStyle
        let phaseStep: Int
        let size: Double
    }

    /// Both renderers draw with fixed colors, so a frame depends only on style, phase and size.
    /// A burst repaints about twelve frames a second; quantizing the phase to 1/100 caps the
    /// cache at ~100 tiny images per style and size and skips a `lockFocus` redraw per frame.
    private static let phaseStepsPerCycle: CGFloat = 100
    private static var frames: [FrameKey: NSImage] = [:]

    static func image(
        style: MenuBarTriggerIconStyle,
        phase: CGFloat = 0,
        size: CGFloat = 13
    ) -> NSImage? {
        guard phase.isFinite, size.isFinite else {
            return render(style: style, phase: phase, size: size)
        }

        let step = Int((phase * phaseStepsPerCycle).rounded())
        let key = FrameKey(style: style, phaseStep: step, size: Double(size))
        if let cached = frames[key] {
            return cached
        }

        guard let image = render(style: style, phase: CGFloat(step) / phaseStepsPerCycle, size: size) else {
            return nil
        }
        frames[key] = image
        return image
    }

    private static func render(style: MenuBarTriggerIconStyle, phase: CGFloat, size: CGFloat) -> NSImage? {
        switch style {
        case .spill:
            return MenuBarTriggerIconDropletRenderer.image(phase: phase, size: size)
        case .symbolizedS:
            return MenuBarTriggerIconSymbolizedSRenderer.image(phase: phase, size: size)
        }
    }
}
