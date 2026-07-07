import AppKit

extension StatusItemController {
    static func trimmedStatusSegments(
        trigger: MenuBarStatusSegment,
        statusSegments: [MenuBarStatusSegment],
        caffeineSegment: MenuBarStatusSegment?,
        maximumWidth: CGFloat,
        layoutStyle: MenuBarStatusLayoutStyle,
        textFontSize: CGFloat,
        textIsBold: Bool,
        acceptsEmptyStatus: Bool
    ) -> [MenuBarStatusSegment]? {
        var visibleStatusSegments = statusSegments
        var fittedSegments = orderedSegments(
            trigger: trigger,
            statusSegments: visibleStatusSegments,
            caffeineSegment: caffeineSegment
        )

        while !visibleStatusSegments.isEmpty,
              !segmentsFit(
                  fittedSegments,
                  maximumWidth: maximumWidth,
                  layoutStyle: layoutStyle,
                  textFontSize: textFontSize,
                  textIsBold: textIsBold
              ) {
            visibleStatusSegments.removeLast()
            fittedSegments = orderedSegments(
                trigger: trigger,
                statusSegments: visibleStatusSegments,
                caffeineSegment: caffeineSegment
            )
        }

        guard acceptsEmptyStatus || !visibleStatusSegments.isEmpty else {
            return nil
        }

        if segmentsFit(
            fittedSegments,
            maximumWidth: maximumWidth,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold
        ) {
            return fittedSegments
        }

        return nil
    }

    static func segmentsFit(
        _ segments: [MenuBarStatusSegment],
        maximumWidth: CGFloat,
        layoutStyle: MenuBarStatusLayoutStyle,
        textFontSize: CGFloat,
        textIsBold: Bool
    ) -> Bool {
        MenuBarStatusContentView.preferredWidth(
            for: segments,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold
        ) <= maximumWidth
    }

}

extension StatusItemController {
    static func maximumStatusItemLength(
        screenWidth: CGFloat?,
        isSleepGuardActive: Bool
    ) -> CGFloat {
        let minimumLength = isSleepGuardActive
            ? activeSleepGuardMaximumStatusItemLength
            : inactiveMaximumStatusItemLength

        guard let screenWidth,
              screenWidth.isFinite,
              screenWidth > 0
        else {
            return minimumLength
        }

        let expandedLength = min(
            expandedMaximumStatusItemLength,
            floor(screenWidth * expandedStatusItemScreenRatio)
        )
        return max(minimumLength, expandedLength)
    }

    var maximumStatusItemLength: CGFloat {
        Self.maximumStatusItemLength(
            screenWidth: statusItemScreenWidth,
            isSleepGuardActive: sleepGuard.isActive
        )
    }

    var statusItemScreenWidth: CGFloat? {
        if let screenWidth = triggerItem.button?.window?.screen?.visibleFrame.width,
           screenWidth > 0 {
            return screenWidth
        }

        return NSScreen.main?.visibleFrame.width
    }
}
