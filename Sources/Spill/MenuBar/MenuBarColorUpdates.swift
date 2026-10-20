import AppKit

/// Menu bar views re-apply colors from `viewDidChangeEffectiveAppearance`, which AppKit can call
/// repeatedly while rendering status item replicants for each display. Assigning only real
/// changes keeps those callbacks from invalidating the views again.
extension NSTextField {
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
