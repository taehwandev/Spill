import AppKit

extension StatusItemController {
    struct RefreshState {
        let hiddenCount: Int
        let summary: MenuBarStatusSummary
        let performanceEffect: MenuBarPerformanceEffect
        let sleepGuardSegment: MenuBarStatusSegment?
        let layoutStyle: MenuBarStatusLayoutStyle
        let textFontSize: CGFloat
        let textIsBold: Bool
        let mainGroupsMainCaffeine: Bool
        let mainSegments: [MenuBarStatusSegment]
        let systemSegments: [MenuBarStatusSegment]
        let aiSegments: [MenuBarStatusSegment]
    }

    struct RefreshChanges {
        let styleChanged: Bool
        let mainSegmentsChanged: Bool
        let systemSegmentsChanged: Bool
        let aiSegmentsChanged: Bool
    }

    func refresh(isSpillBarVisible: Bool? = nil) {
        if let isSpillBarVisible {
            self.isSpillBarVisible = isSpillBarVisible
        }

        let state = makeRefreshState()
        let changes = updateCurrentState(from: state)
        let statusTooltip = statusTooltip(
            summary: state.summary,
            sleepGuardSegment: state.sleepGuardSegment,
            performanceEffect: state.performanceEffect
        )
        applyRefreshState(state, changes: changes, statusTooltip: statusTooltip)
    }
}

extension StatusItemController {
    func makeRefreshState() -> RefreshState {
        let hiddenCount = hiddenItemCountProvider()
        let tokenCounts = aiTokenCountProvider()
        let summary = MenuBarStatusSummary.make(
            enabledItems: settings.enabledMenuBarStatusItems,
            cpu: statusStore.cpu,
            memory: statusStore.memory,
            aiTokenCount: tokenCounts.daily,
            aiAllTimeTokenCount: tokenCounts.total,
            displayMode: settings.menuBarTokenDisplayMode,
            aiServerHealth: aiServerHealthProvider(),
            precision: settings.menuBarStatusPrecision,
            highlightThreshold: settings.menuBarStatusHighlightThreshold
        )
        let performanceEffect = menuBarPerformanceEffect
        let sleepGuardSegment = sleepGuardMenuBarSegment
        let compactMode = settings.menuBarStatusCompactMode
        let splitGroups = settings.menuBarStatusSplitGroups
        let layoutStyle: MenuBarStatusLayoutStyle = compactMode ? settings.menuBarStatusLayoutStyle : .inline
        let textFontSize = MenuBarStatusContentView.normalizedTextFontSize(
            CGFloat(settings.menuBarStatusFontSize)
        )
        let textIsBold = settings.menuBarStatusTextBold
        let trigger = triggerSegment(performanceEffect: performanceEffect)
        let displayStatusSegments = compactMode
            ? summary.segments.map { $0.valueOnlyMenuBarSegment() }
            : summary.segments
        let displaySleepGuardSegment = compactMode
            ? sleepGuardSegment?.badgeMenuBarSegment()
            : sleepGuardSegment
        let mainGroupsMainCaffeine = compactMode && splitGroups

        let segments = refreshSegments(
            trigger: trigger,
            statusSegments: displayStatusSegments,
            caffeineSegment: displaySleepGuardSegment,
            splitGroups: splitGroups,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold,
            usesCompactFallback: compactMode
        )

        return RefreshState(
            hiddenCount: hiddenCount,
            summary: summary,
            performanceEffect: performanceEffect,
            sleepGuardSegment: sleepGuardSegment,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold,
            mainGroupsMainCaffeine: mainGroupsMainCaffeine,
            mainSegments: segments.main,
            systemSegments: segments.system,
            aiSegments: segments.ai
        )
    }

    func refreshSegments(
        trigger: MenuBarStatusSegment,
        statusSegments: [MenuBarStatusSegment],
        caffeineSegment: MenuBarStatusSegment?,
        splitGroups: Bool,
        layoutStyle: MenuBarStatusLayoutStyle,
        textFontSize: CGFloat,
        textIsBold: Bool,
        usesCompactFallback: Bool
    ) -> (main: [MenuBarStatusSegment], system: [MenuBarStatusSegment], ai: [MenuBarStatusSegment]) {
        if splitGroups {
            return (
                main: Self.orderedSegments(trigger: trigger, statusSegments: [], caffeineSegment: caffeineSegment),
                system: statusSegments.filter { $0.kind == .cpu || $0.kind == .memory },
                ai: statusSegments.filter { $0.kind == .ai }
            )
        }

        return (
            main: Self.visibleSegments(
                trigger: trigger,
                statusSegments: statusSegments,
                caffeineSegment: caffeineSegment,
                maximumWidth: maximumStatusItemLength,
                layoutStyle: layoutStyle,
                textFontSize: textFontSize,
                textIsBold: textIsBold,
                usesCompactFallback: usesCompactFallback
            ),
            system: [],
            ai: []
        )
    }
}
