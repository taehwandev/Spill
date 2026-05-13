import AppKit
import CoreGraphics

struct NotchDetector {
    private let horizontalClearance: CGFloat = 44
    private let geometry: MenuBarNotchGeometry

    init(geometry: MenuBarNotchGeometry) {
        self.geometry = geometry
    }

    func intersectsNotchEstimate(_ frame: CGRect) -> Bool {
        guard !frame.isNull, !frame.isEmpty, frame.width.isFinite, frame.height.isFinite else {
            return false
        }

        let notch = geometry.expandedNotchFrame(horizontalClearance: horizontalClearance, verticalClearance: 8)
        let horizontalOverlap = frame.maxX >= notch.minX && frame.minX <= notch.maxX
        guard horizontalOverlap else {
            return false
        }

        let topOriginNotch = CGRect(
            x: notch.minX,
            y: geometry.screenFrame.minY,
            width: notch.width,
            height: notch.height
        )

        return topOriginNotch.intersects(frame) || notch.intersects(frame)
    }
}
