import CoreGraphics

enum SpillGlanceLayout {
    static let contentHeight: CGFloat = 30
    static let itemSpacing: CGFloat = 0
    static let separatorWidth: CGFloat = 1
    static let settingsControlWidth: CGFloat = 28
    static let topInset: CGFloat = 10
    static let horizontalScreenInset: CGFloat = 8

    static func itemWidth(for module: SpillGlanceModule) -> CGFloat {
        switch module {
        case .allToday:
            return 68
        case .codexToday, .claudeToday, .antigravityToday:
            return 54
        case .workType:
            return 112
        }
    }

    static func contentSize(
        modules: [SpillGlanceModule],
        spacing: CGFloat = itemSpacing,
        height: CGFloat = contentHeight
    ) -> CGSize {
        guard !modules.isEmpty else {
            return .zero
        }

        return contentSize(
            itemWidths: modules.map(itemWidth(for:)) + [settingsControlWidth],
            spacing: spacing,
            height: height
        )
    }

    static func contentSize(
        itemWidths: [CGFloat],
        spacing: CGFloat = itemSpacing,
        height: CGFloat = contentHeight
    ) -> CGSize {
        let normalizedWidths = itemWidths.map { max(0, $0) }
        let boundaryCount = CGFloat(max(normalizedWidths.count - 1, 0))
        let totalSpacing = boundaryCount * (max(0, spacing) + separatorWidth)
        return CGSize(
            width: normalizedWidths.reduce(0, +) + totalSpacing,
            height: max(0, min(height, 34))
        )
    }

    static func panelFrame(
        contentSize: CGSize,
        visibleFrame: CGRect,
        topInset: CGFloat = topInset
    ) -> CGRect {
        let maximumWidth = max(0, visibleFrame.width - (horizontalScreenInset * 2))
        let width = min(max(0, contentSize.width), maximumWidth)
        let height = min(max(0, contentSize.height), min(34, max(0, visibleFrame.height)))
        let proposedFrame = CGRect(
            x: visibleFrame.midX - (width / 2),
            y: visibleFrame.maxY - height - max(0, topInset),
            width: width,
            height: height
        )
        return constrainedFrame(proposedFrame, visibleFrame: visibleFrame)
    }

    static func draggedFrame(
        initialFrame: CGRect,
        initialPointerLocation: CGPoint,
        currentPointerLocation: CGPoint,
        visibleFrame: CGRect
    ) -> CGRect {
        let proposedFrame = initialFrame.offsetBy(
            dx: currentPointerLocation.x - initialPointerLocation.x,
            dy: currentPointerLocation.y - initialPointerLocation.y
        )
        return constrainedFrame(proposedFrame, visibleFrame: visibleFrame)
    }

    static func constrainedFrame(
        _ frame: CGRect,
        visibleFrame: CGRect
    ) -> CGRect {
        let width = min(max(0, frame.width), max(0, visibleFrame.width - (horizontalScreenInset * 2)))
        let height = min(max(0, frame.height), min(34, max(0, visibleFrame.height)))
        let minimumX = visibleFrame.minX + min(horizontalScreenInset, visibleFrame.width / 2)
        let maximumX = max(minimumX, visibleFrame.maxX - horizontalScreenInset - width)
        let minimumY = visibleFrame.minY
        let maximumY = max(minimumY, visibleFrame.maxY - topInset - height)
        let x = min(max(frame.minX, minimumX), maximumX)
        let y = min(max(frame.minY, minimumY), maximumY)

        return CGRect(
            x: x.rounded(.toNearestOrAwayFromZero),
            y: y.rounded(.toNearestOrAwayFromZero),
            width: width,
            height: height
        )
    }
}
