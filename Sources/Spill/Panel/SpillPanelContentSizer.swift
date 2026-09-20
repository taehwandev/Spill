import AppKit

enum SpillPanelContentSizer {
    private static let verticalPadding: CGFloat = 20
    private static let topLevelSpacing: CGFloat = 14
    private static let dividerHeight: CGFloat = 1
    private static let updateBannerHeight: CGFloat = 38
    private static let sectionHeaderHeight: CGFloat = 14
    private static let statusSectionSpacing: CGFloat = 6
    private static let sectionContentSpacing: CGFloat = 5
    private static let aiSectionSpacing: CGFloat = 7
    private static let tokenMeteringHeight: CGFloat = 82
    private static let statusRowHeight: CGFloat = 64
    private static let statusRowSpacing: CGFloat = 7
    private static let windowActionHeight: CGFloat = 58
    private static let windowActionSpacing: CGFloat = 6
}

extension SpillPanelContentSizer {
    static func preferredSize(
        statusModuleCount: Int,
        showsTokenMetering: Bool = false,
        windowActionCount: Int,
        visibleFrame: NSRect,
        showsUpdateBanner: Bool = false
    ) -> NSSize {
        let width = preferredWidth(visibleFrame: visibleFrame)
        let showsStatusSection = statusModuleCount > 0
        let showsAISection = showsTokenMetering
        let dividerCount = 1 + (showsStatusSection ? 1 : 0) + (showsAISection ? 1 : 0)
        let topLevelChildCount = 3
            + (showsUpdateBanner ? 1 : 0)
            + (showsStatusSection ? 2 : 0)
            + (showsAISection ? 2 : 0)
        let topLevelGapHeight = CGFloat(max(0, topLevelChildCount - 1)) * topLevelSpacing
        let dividerTotalHeight = CGFloat(dividerCount) * dividerHeight
        let desiredHeight = verticalPadding
            + 34
            + (showsUpdateBanner ? updateBannerHeight : 0)
            + topLevelGapHeight
            + dividerTotalHeight
            + statusSectionHeight(moduleCount: statusModuleCount)
            + aiSectionHeight(showsTokenMetering: showsTokenMetering)
            + windowActionsSectionHeight(actionCount: windowActionCount)
        let height = boundedHeight(desiredHeight, visibleFrame: visibleFrame)

        return NSSize(width: width, height: height)
    }

    static func preferredWidth(visibleFrame: NSRect) -> CGFloat {
        let availableWidth = max(
            SpillPanelMetrics.minimumSize.width,
            visibleFrame.width - SpillPanelMetrics.edgeInset * 2
        )
        let maximumWidth = min(SpillPanelMetrics.maximumWidth, availableWidth)

        return min(max(SpillPanelMetrics.defaultWidth, SpillPanelMetrics.minimumSize.width), maximumWidth)
    }

    static func boundedHeight(_ desiredHeight: CGFloat, visibleFrame: NSRect) -> CGFloat {
        let availableHeight = max(
            SpillPanelMetrics.minimumSize.height,
            visibleFrame.height - SpillPanelMetrics.edgeInset * 2
        )

        return min(max(desiredHeight.rounded(.up), SpillPanelMetrics.minimumSize.height), availableHeight)
    }
}

private extension SpillPanelContentSizer {
    private static func statusSectionHeight(moduleCount: Int) -> CGFloat {
        guard moduleCount > 0 else {
            return 0
        }

        return sectionHeaderHeight
            + statusSectionSpacing
            + rowsHeight(count: moduleCount, itemHeight: statusRowHeight, spacing: statusRowSpacing)
    }

    private static func aiSectionHeight(showsTokenMetering: Bool) -> CGFloat {
        guard showsTokenMetering else { return 0 }
        return sectionHeaderHeight + aiSectionSpacing + tokenMeteringHeight
    }

    private static func windowActionsSectionHeight(actionCount: Int) -> CGFloat {
        guard actionCount > 0 else {
            return sectionHeaderHeight + sectionContentSpacing + windowActionHeight
        }

        // Side-by-side layout: 3 rows of buttons + header label space (15 pt)
        let gridHeight = rowsHeight(count: 3, itemHeight: windowActionHeight, spacing: windowActionSpacing)
        let customHeaderHeight: CGFloat = 15

        return sectionHeaderHeight
            + sectionContentSpacing
            + gridHeight
            + customHeaderHeight
    }

    private static func rowsHeight(count: Int, itemHeight: CGFloat, spacing: CGFloat) -> CGFloat {
        guard count > 0 else {
            return 0
        }

        return CGFloat(count) * itemHeight + CGFloat(count - 1) * spacing
    }

}
