import CoreGraphics

enum SpillGlanceLayout {
    static let contentHeight: CGFloat = 30
    static let itemSpacing: CGFloat = 0
    static let separatorWidth: CGFloat = 1
    static let settingsControlWidth: CGFloat = 28
    static let tickerItemWidth: CGFloat = 180
    static let topInset: CGFloat = 10
    static let horizontalScreenInset: CGFloat = 8
    static let bottomScreenInset: CGFloat = 8
    static let anchorSnapDistance: CGFloat = 24
    static let cornerRadius: CGFloat = 15

    static func itemWidth(for module: SpillGlanceModule) -> CGFloat {
        switch module {
        case .allToday:
            return 98
        case .codexToday, .claudeToday, .antigravityToday:
            return 100
        case .workType:
            return 180
        }
    }

    static func contentSize(
        modules: [SpillGlanceModule],
        displayStyle: SpillGlanceDisplayStyle = .all,
        spacing: CGFloat = itemSpacing,
        height: CGFloat = contentHeight
    ) -> CGSize {
        guard !modules.isEmpty else {
            return .zero
        }

        let itemWidths = displayStyle == .ticker
            ? [tickerItemWidth, settingsControlWidth]
            : modules.map(itemWidth(for:)) + [settingsControlWidth]
        return contentSize(
            itemWidths: itemWidths,
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
        let maximumHeight = max(0, visibleFrame.height - max(0, topInset) - bottomScreenInset)
        let height = min(min(max(0, contentSize.height), 34), maximumHeight)
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
        let maximumHeight = max(0, visibleFrame.height - topInset - bottomScreenInset)
        let height = min(max(0, frame.height), maximumHeight)
        let allowedX = allowedOriginXRange(contentWidth: width, visibleFrame: visibleFrame)
        let allowedY = allowedOriginYRange(contentHeight: height, visibleFrame: visibleFrame)
        let x = min(max(frame.minX, allowedX.lowerBound), allowedX.upperBound)
        let y = min(max(frame.minY, allowedY.lowerBound), allowedY.upperBound)

        return CGRect(
            x: x.rounded(.toNearestOrAwayFromZero),
            y: y.rounded(.toNearestOrAwayFromZero),
            width: width,
            height: height
        )
    }

    static func allowedOriginXRange(
        contentWidth: CGFloat,
        visibleFrame: CGRect
    ) -> ClosedRange<CGFloat> {
        let minimumX = visibleFrame.minX + min(horizontalScreenInset, visibleFrame.width / 2)
        let maximumX = max(minimumX, visibleFrame.maxX - horizontalScreenInset - max(0, contentWidth))
        return minimumX ... maximumX
    }

    static func allowedOriginYRange(
        contentHeight: CGFloat,
        visibleFrame: CGRect
    ) -> ClosedRange<CGFloat> {
        let minimumY = visibleFrame.minY + min(bottomScreenInset, visibleFrame.height / 2)
        let maximumY = max(minimumY, visibleFrame.maxY - topInset - max(0, contentHeight))
        return minimumY ... maximumY
    }
}
