import AppKit

extension NSRect {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> NSRect {
        NSRect(x: origin.x + dx, y: origin.y + dy, width: size.width, height: size.height)
    }
}
