import AppKit

extension StatusItemController {
    func updateCurrentState(from state: RefreshState) -> RefreshChanges {
        let layoutChanged = state.layoutStyle != currentLayoutStyle
        let fontSizeChanged = state.textFontSize != currentMenuBarStatusFontSize
        let fontWeightChanged = state.textIsBold != currentMenuBarStatusTextBold
        let compactModeChanged = settings.menuBarStatusCompactMode != currentMenuBarStatusCompactMode
        let splitGroupsChanged = settings.menuBarStatusSplitGroups != currentMenuBarStatusSplitGroups
        let mainGroupingChanged = state.mainGroupsMainCaffeine != currentMainGroupsMainCaffeine
        let styleChanged = layoutChanged
            || fontSizeChanged
            || fontWeightChanged
            || compactModeChanged
            || splitGroupsChanged
            || mainGroupingChanged

        let changes = RefreshChanges(
            styleChanged: styleChanged,
            mainSegmentsChanged: state.mainSegments != currentMainSegments,
            systemSegmentsChanged: state.systemSegments != currentSystemSegments,
            aiSegmentsChanged: state.aiSegments != currentAISegments
        )

        currentMainSegments = state.mainSegments
        currentSystemSegments = state.systemSegments
        currentAISegments = state.aiSegments
        currentLayoutStyle = state.layoutStyle
        currentMenuBarStatusFontSize = state.textFontSize
        currentMenuBarStatusTextBold = state.textIsBold
        currentMenuBarStatusCompactMode = settings.menuBarStatusCompactMode
        currentMenuBarStatusSplitGroups = settings.menuBarStatusSplitGroups
        currentMainGroupsMainCaffeine = state.mainGroupsMainCaffeine
        return changes
    }

    func applyRefreshState(
        _ state: RefreshState,
        changes: RefreshChanges,
        statusTooltip: String
    ) {
        applySegments(
            state.mainSegments,
            to: triggerItem,
            contentView: &mainStatusContentView,
            statusTooltip: statusTooltip,
            layoutStyle: state.layoutStyle,
            textFontSize: state.textFontSize,
            textIsBold: state.textIsBold,
            groupsMainCaffeine: state.mainGroupsMainCaffeine,
            isVisible: true,
            rebuildsContentView: changes.mainSegmentsChanged || changes.styleChanged
        )
        applySegments(
            state.systemSegments,
            to: systemItem,
            contentView: &systemStatusContentView,
            statusTooltip: segmentTooltip(for: state.systemSegments),
            layoutStyle: state.layoutStyle,
            textFontSize: state.textFontSize,
            textIsBold: state.textIsBold,
            groupsMainCaffeine: false,
            isVisible: !state.systemSegments.isEmpty,
            rebuildsContentView: changes.systemSegmentsChanged || changes.styleChanged
        )
        applySegments(
            state.aiSegments,
            to: aiItem,
            contentView: &aiStatusContentView,
            statusTooltip: segmentTooltip(for: state.aiSegments),
            layoutStyle: state.layoutStyle,
            textFontSize: state.textFontSize,
            textIsBold: state.textIsBold,
            groupsMainCaffeine: false,
            isVisible: !state.aiSegments.isEmpty,
            rebuildsContentView: changes.aiSegmentsChanged || changes.styleChanged
        )

        triggerItem.button?.state = self.isSpillBarVisible ? .on : .off
        triggerItem.button?.toolTip = tooltip(
            statusTooltip: statusTooltip,
            hiddenCount: state.hiddenCount,
            isSpillBarVisible: self.isSpillBarVisible
        )
        systemItem.button?.toolTip = segmentTooltip(for: state.systemSegments)
        aiItem.button?.toolTip = segmentTooltip(for: state.aiSegments)
    }
}

extension StatusItemController {
    var buttonScreenFrame: NSRect? {
        guard let button = triggerItem.button,
              let window = button.window
        else {
            return nil
        }

        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        if buttonFrame.width > 0, buttonFrame.height > 0 {
            return buttonFrame
        }

        let windowFrame = window.frame
        guard windowFrame.width > 0, windowFrame.height > 0 else {
            return nil
        }

        return windowFrame
    }

    func performPrimaryClickForSmokeTest() {
        triggerItem.button?.performClick(nil)
    }

    static func orderedSegments(
        trigger: MenuBarStatusSegment,
        statusSegments: [MenuBarStatusSegment],
        caffeineSegment: MenuBarStatusSegment?
    ) -> [MenuBarStatusSegment] {
        [caffeineSegment].compactMap { $0 } + [trigger] + statusSegments
    }

    static func visibleSegments(
        trigger: MenuBarStatusSegment,
        statusSegments: [MenuBarStatusSegment],
        caffeineSegment: MenuBarStatusSegment?,
        maximumWidth: CGFloat,
        layoutStyle: MenuBarStatusLayoutStyle = .inline,
        textFontSize: CGFloat = MenuBarStatusContentView.defaultTextFontSize,
        textIsBold: Bool = false,
        usesCompactFallback: Bool = true
    ) -> [MenuBarStatusSegment] {
        let requestedSegments = orderedSegments(
            trigger: trigger,
            statusSegments: statusSegments,
            caffeineSegment: caffeineSegment
        )
        if segmentsFit(
            requestedSegments,
            maximumWidth: maximumWidth,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold
        ) {
            return requestedSegments
        }

        guard usesCompactFallback else {
            return regularVisibleSegments(
                trigger: trigger,
                statusSegments: statusSegments,
                caffeineSegment: caffeineSegment,
                maximumWidth: maximumWidth,
                layoutStyle: layoutStyle,
                textFontSize: textFontSize,
                textIsBold: textIsBold
            )
        }

        return compactVisibleSegments(
            trigger: trigger,
            statusSegments: statusSegments,
            caffeineSegment: caffeineSegment,
            maximumWidth: maximumWidth,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold
        )
    }
}
