import AppKit

extension StatusItemController {
    static func regularVisibleSegments(
        trigger: MenuBarStatusSegment,
        statusSegments: [MenuBarStatusSegment],
        caffeineSegment: MenuBarStatusSegment?,
        maximumWidth: CGFloat,
        layoutStyle: MenuBarStatusLayoutStyle,
        textFontSize: CGFloat,
        textIsBold: Bool
    ) -> [MenuBarStatusSegment] {
        trimmedStatusSegments(
            trigger: trigger,
            statusSegments: statusSegments,
            caffeineSegment: caffeineSegment,
            maximumWidth: maximumWidth,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold,
            acceptsEmptyStatus: true
        ) ?? [trigger]
    }
}

extension StatusItemController {
    static func compactVisibleSegments(
        trigger: MenuBarStatusSegment,
        statusSegments: [MenuBarStatusSegment],
        caffeineSegment: MenuBarStatusSegment?,
        maximumWidth: CGFloat,
        layoutStyle: MenuBarStatusLayoutStyle,
        textFontSize: CGFloat,
        textIsBold: Bool
    ) -> [MenuBarStatusSegment] {
        let compactCaffeineSegment = caffeineSegment?.badgeMenuBarSegment()
        let compactStatusSegments = statusSegments.map { $0.valueOnlyMenuBarSegment() }
        if let fittedSegments = trimmedStatusSegments(
            trigger: trigger,
            statusSegments: compactStatusSegments,
            caffeineSegment: compactCaffeineSegment,
            maximumWidth: maximumWidth,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold,
            acceptsEmptyStatus: statusSegments.isEmpty
        ) {
            return fittedSegments
        }

        let essentialSegments = orderedSegments(
            trigger: trigger,
            statusSegments: [],
            caffeineSegment: compactCaffeineSegment
        )
        if segmentsFit(
            essentialSegments,
            maximumWidth: maximumWidth,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold
        ) {
            return essentialSegments
        }

        return trimmedStatusSegments(
            trigger: trigger,
            statusSegments: compactStatusSegments,
            caffeineSegment: nil,
            maximumWidth: maximumWidth,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold,
            acceptsEmptyStatus: false
        ) ?? [trigger]
    }
}
