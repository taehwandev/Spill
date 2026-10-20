import AppKit

/// Assign semantic colors only when their value changes. Drawing resolves their appearance;
/// status-item replicant passes must not reassign them from appearance callbacks.
extension MenuBarStatusTextView {
    func setTextColorIfChanged(_ color: NSColor?) {
        guard textColor != color else {
            return
        }
        textColor = color
    }
}

extension NSImageView {
    func setContentTintColorIfChanged(_ color: NSColor?) {
        guard contentTintColor != color else {
            return
        }
        contentTintColor = color
    }
}
