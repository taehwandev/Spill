import AppKit

/// Read-only status text without NSTextField's appearance-dependent control layout.
/// Status-item replicants may alternate drawing appearances for different displays.
@MainActor
final class MenuBarStatusTextView: NSView {
    var stringValue: String {
        didSet {
            guard stringValue != oldValue else { return }
            invalidateTextMetrics()
            setAccessibilityValue(stringValue)
        }
    }
    var font: NSFont? = .systemFont(ofSize: NSFont.systemFontSize) {
        didSet {
            guard font != oldValue else { return }
            invalidateTextMetrics()
        }
    }
    var textColor: NSColor? = .labelColor {
        didSet {
            if textColor != oldValue { needsDisplay = true }
        }
    }
    var alignment: NSTextAlignment = .left {
        didSet {
            if alignment != oldValue { needsDisplay = true }
        }
    }
    private var measuredSize: NSSize?

    init(labelWithString string: String) {
        stringValue = string
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityValue(string)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        if let measuredSize { return measuredSize }
        let size = (stringValue as NSString).size(withAttributes: [.font: resolvedFont])
        let measured = NSSize(width: ceil(size.width), height: ceil(size.height))
        measuredSize = measured
        return measured
    }

    override func draw(_ dirtyRect: NSRect) {
        let size = intrinsicContentSize
        let x: CGFloat
        switch alignment {
        case .center: x = (bounds.width - size.width) / 2
        case .right: x = bounds.width - size.width
        default: x = 0
        }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: bounds).addClip()
        (stringValue as NSString).draw(
            at: NSPoint(x: x, y: (bounds.height - size.height) / 2),
            withAttributes: [.font: resolvedFont, .foregroundColor: textColor ?? .labelColor]
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    private var resolvedFont: NSFont { font ?? .systemFont(ofSize: NSFont.systemFontSize) }

    private func invalidateTextMetrics() {
        measuredSize = nil
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }
}
