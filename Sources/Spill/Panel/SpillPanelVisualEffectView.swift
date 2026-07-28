import AppKit
import SwiftUI

@MainActor
final class SpillPanelVisualEffectView: NSVisualEffectView {
    static let cornerRadius: CGFloat = 22

    private var materialMaskSize = NSSize.zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureRoundedMaterial()
        updateMaterialMaskIfNeeded()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureRoundedMaterial()
        updateMaterialMaskIfNeeded()
    }

    override func layout() {
        super.layout()
        updateMaterialMaskIfNeeded()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateMaterialMaskIfNeeded()
    }

    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        updateMaterialMaskIfNeeded()
    }

    private func configureRoundedMaterial() {
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    private func updateMaterialMaskIfNeeded() {
        let size = bounds.size
        guard size.width > 0, size.height > 0, size != materialMaskSize else {
            return
        }

        materialMaskSize = size
        maskImage = Self.continuousRoundedMask(size: size)
    }

    private static func continuousRoundedMask(size: NSSize) -> NSImage {
        NSImage(size: size, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }

            let radius = min(Self.cornerRadius, min(bounds.width, bounds.height) / 2)
            let path = RoundedRectangle(cornerRadius: radius, style: .continuous)
                .path(in: bounds)
                .cgPath
            context.addPath(path)
            context.setFillColor(NSColor.white.cgColor)
            context.fillPath()
            return true
        }
    }
}
