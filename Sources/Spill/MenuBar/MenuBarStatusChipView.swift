import AppKit

/// A chip inside a shared status item. macOS reports only which status item was clicked, so each
/// chip resolves the click itself from its own laid-out subviews rather than from geometry the
/// menu bar is free to change between releases.
@MainActor
protocol MenuBarStatusChipView: NSView {
    /// - Parameter point: the click, in this chip's coordinates.
    func chipSegmentKind(at point: NSPoint) -> MenuBarStatusSegment.Kind?
}
