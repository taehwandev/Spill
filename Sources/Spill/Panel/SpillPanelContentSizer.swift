import AppKit

enum SpillPanelContentSizer {
    private static let horizontalPadding: CGFloat = 28
    private static let verticalPadding: CGFloat = 20
    private static let topLevelSpacing: CGFloat = 10
    private static let sectionHeaderHeight: CGFloat = 14
    private static let statusSectionSpacing: CGFloat = 6
    private static let sectionContentSpacing: CGFloat = 5
    private static let statusRowHeight: CGFloat = 56
    private static let statusRowSpacing: CGFloat = 7
    private static let aiPillHeight: CGFloat = 60
    private static let windowActionWidth: CGFloat = 76
    private static let windowActionHeight: CGFloat = 50
    private static let windowActionSpacing: CGFloat = 6
    private static let menuBarActionWidth: CGFloat = 48
    private static let menuBarActionHeight: CGFloat = 48
    private static let menuBarActionRowSpacing: CGFloat = 6
    private static let inlineActionStateHeight: CGFloat = 48
    private static let footerHeight: CGFloat = 32
    private static let actionSectionSpacing: CGFloat = 7

    static func preferredSize(
        statusModuleCount: Int,
        aiStatusCount: Int,
        windowActionCount: Int,
        menuBarActionCount: Int,
        iconSpacing: CGFloat,
        visibleFrame: NSRect
    ) -> NSSize {
        let width = preferredWidth(visibleFrame: visibleFrame)
        let contentWidth = max(0, width - horizontalPadding)
        let sectionCount = statusModuleCount > 0 ? 5 : 4
        let topLevelGapHeight = CGFloat(max(0, sectionCount - 1)) * topLevelSpacing
        let desiredHeight = verticalPadding
            + 34
            + topLevelGapHeight
            + statusSectionHeight(moduleCount: statusModuleCount)
            + aiSectionHeight(statusCount: aiStatusCount)
            + actionSectionsHeight(
                windowActionCount: windowActionCount,
                menuBarActionCount: menuBarActionCount,
                contentWidth: contentWidth,
                iconSpacing: iconSpacing
            )
            + footerHeight
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

    private static func statusSectionHeight(moduleCount: Int) -> CGFloat {
        guard moduleCount > 0 else {
            return 0
        }

        return sectionHeaderHeight
            + statusSectionSpacing
            + rowsHeight(count: moduleCount, itemHeight: statusRowHeight, spacing: statusRowSpacing)
    }

    private static func aiSectionHeight(statusCount: Int) -> CGFloat {
        guard statusCount > 0 else {
            return sectionHeaderHeight
        }

        return sectionHeaderHeight + sectionContentSpacing + aiPillHeight
    }

    private static func actionSectionsHeight(
        windowActionCount: Int,
        menuBarActionCount: Int,
        contentWidth: CGFloat,
        iconSpacing: CGFloat
    ) -> CGFloat {
        windowActionsSectionHeight(actionCount: windowActionCount, contentWidth: contentWidth)
            + actionSectionSpacing
            + menuBarActionsSectionHeight(
                actionCount: menuBarActionCount,
                contentWidth: contentWidth,
                iconSpacing: iconSpacing
            )
    }

    private static func windowActionsSectionHeight(actionCount: Int, contentWidth: CGFloat) -> CGFloat {
        sectionHeaderHeight
            + sectionContentSpacing
            + actionGridHeight(
                actionCount: actionCount,
                contentWidth: contentWidth,
                itemWidth: windowActionWidth,
                itemHeight: windowActionHeight,
                columnSpacing: windowActionSpacing,
                rowSpacing: windowActionSpacing,
                emptyHeight: windowActionHeight
            )
    }

    private static func menuBarActionsSectionHeight(
        actionCount: Int,
        contentWidth: CGFloat,
        iconSpacing: CGFloat
    ) -> CGFloat {
        let columnSpacing = max(iconSpacing, 7)

        return sectionHeaderHeight
            + sectionContentSpacing
            + actionGridHeight(
                actionCount: actionCount,
                contentWidth: contentWidth,
                itemWidth: menuBarActionWidth,
                itemHeight: menuBarActionHeight,
                columnSpacing: columnSpacing,
                rowSpacing: menuBarActionRowSpacing,
                emptyHeight: inlineActionStateHeight
            )
    }

    private static func actionGridHeight(
        actionCount: Int,
        contentWidth: CGFloat,
        itemWidth: CGFloat,
        itemHeight: CGFloat,
        columnSpacing: CGFloat,
        rowSpacing: CGFloat,
        emptyHeight: CGFloat
    ) -> CGFloat {
        guard actionCount > 0 else {
            return emptyHeight
        }

        let columns = adaptiveColumnCount(contentWidth: contentWidth, itemWidth: itemWidth, spacing: columnSpacing)
        let rows = Int(ceil(Double(actionCount) / Double(columns)))

        return rowsHeight(count: rows, itemHeight: itemHeight, spacing: rowSpacing)
    }

    private static func rowsHeight(count: Int, itemHeight: CGFloat, spacing: CGFloat) -> CGFloat {
        guard count > 0 else {
            return 0
        }

        return CGFloat(count) * itemHeight + CGFloat(count - 1) * spacing
    }

    private static func adaptiveColumnCount(contentWidth: CGFloat, itemWidth: CGFloat, spacing: CGFloat) -> Int {
        max(1, Int((contentWidth + spacing) / (itemWidth + spacing)))
    }
}
