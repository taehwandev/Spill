import AppKit
import CoreGraphics

struct MenuBarNotchGeometry: Sendable {
    private let auxiliaryTopLeftArea: CGRect?
    private let auxiliaryTopRightArea: CGRect?
    let screenFrame: CGRect
    let safeAreaTop: CGFloat

    init(screen: NSScreen?) {
        let screen = screen ?? NSScreen.main ?? NSScreen.screens.first
        screenFrame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1512, height: 982)
        auxiliaryTopLeftArea = screen?.auxiliaryTopLeftArea
        auxiliaryTopRightArea = screen?.auxiliaryTopRightArea
        safeAreaTop = screen?.safeAreaInsets.top ?? 0
    }

    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
        auxiliaryTopLeftArea = nil
        auxiliaryTopRightArea = nil
        safeAreaTop = 0
    }

    var hasHardwareNotch: Bool {
        measuredNotchFrame != nil || safeAreaTop > 0
    }

    var notchFrame: CGRect {
        measuredNotchFrame ?? estimatedNotchFrame
    }

    func expandedNotchFrame(horizontalClearance: CGFloat, verticalClearance: CGFloat) -> CGRect {
        notchFrame.insetBy(dx: -horizontalClearance, dy: -verticalClearance)
    }

    private var measuredNotchFrame: CGRect? {
        guard let left = auxiliaryTopLeftArea,
              let right = auxiliaryTopRightArea,
              right.minX > left.maxX
        else {
            return nil
        }

        let height = max(safeAreaTop, left.height, right.height, 32)
        let y = max(screenFrame.minY, min(left.minY, right.minY))

        return CGRect(
            x: left.maxX,
            y: y,
            width: right.minX - left.maxX,
            height: height
        )
    }

    private var estimatedNotchFrame: CGRect {
        let width = min(max(screenFrame.width * 0.13, 170), 260)
        let height: CGFloat = 42

        return CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
    }
}
