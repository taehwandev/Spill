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

        // Applying a tick mid-click tears down and shifts the chips under the cursor,
        // so the mouseUp can miss the button or hit-test against a moved layout.
        // Hold this tick until the press ends; the deferred retry re-applies it.
        guard !isMouseInteractingWithStatusItems else {
            scheduleRefreshAfterInteraction()
            return
        }

        let state = makeRefreshState()
        let changes = updateCurrentState(from: state)
        let statusTooltip = statusTooltip(
            summary: state.summary,
            sleepGuardSegment: state.sleepGuardSegment,
            performanceEffect: state.performanceEffect
        )
        applyRefreshState(state, changes: changes, statusTooltip: statusTooltip)
        updateTriggerIconAnimator(usageRatio: state.performanceEffect.usageRatio)
    }

    /// The shared animator is started/stopped here — tied to settings, once per refresh —
    /// rather than from `MenuBarMetricChipView`'s lifecycle, since that view is torn down and
    /// rebuilt almost every refresh and must not own the animation timer itself (see
    /// `TriggerIconAnimator`). `noteUsageRatio` is fed the app's already-computed combined
    /// CPU/memory/network load so idle-triggered bursts can occasionally run early (and a
    /// touch faster) when real system activity jumps, without requiring those stat modules to
    /// be polled just for this (the reading is simply `.calm`/0 if they aren't already active).
    private func updateTriggerIconAnimator(usageRatio: Double) {
        let shouldAnimate = settings.useSpillAnimation && settings.menuBarTriggerIconStyle.animates
        if shouldAnimate {
            TriggerIconAnimator.shared.start()
            TriggerIconAnimator.shared.noteUsageRatio(usageRatio)
        } else {
            TriggerIconAnimator.shared.stop()
        }
    }
}

extension StatusItemController {
    var statusItemWindows: [NSWindow] {
        [triggerItem, systemItem, aiItem].compactMap { $0.button?.window }
    }

    private var isMouseInteractingWithStatusItems: Bool {
        Self.isMouseInteracting(
            pressedMouseButtons: pressedMouseButtonsProvider(),
            mouseLocation: mouseLocationProvider(),
            statusWindowFrames: statusItemWindows.map(\.frame)
        )
    }

    static func isMouseInteracting(
        pressedMouseButtons: Int,
        mouseLocation: NSPoint,
        statusWindowFrames: [NSRect]
    ) -> Bool {
        guard pressedMouseButtons != 0 else {
            return false
        }

        return statusWindowFrames.contains { $0.contains(mouseLocation) }
    }

    private func scheduleRefreshAfterInteraction() {
        guard !isDeferredRefreshScheduled else {
            return
        }

        isDeferredRefreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else {
                return
            }

            self.isDeferredRefreshScheduled = false
            self.refresh()
        }
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
            network: statusStore.network,
            cpuHistory: statusStore.history(for: .cpu),
            memoryHistory: statusStore.history(for: .memory),
            networkHistory: statusStore.networkTrafficHistory,
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
        let presentationStyles = settings.menuBarMetricPresentationStyles
        let layoutStyle = settings.menuBarStatusLayoutStyle
        let textFontSize = MenuBarStatusContentView.normalizedTextFontSize(
            CGFloat(settings.menuBarStatusFontSize)
        )
        let textIsBold = settings.menuBarStatusTextBold
        let trigger = triggerSegment(performanceEffect: performanceEffect)
        let displayStatusSegments = Self.displayStatusSegments(
            summary.segments,
            presentationStyles: presentationStyles,
            compactMode: compactMode
        )
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

    static func displayStatusSegments(
        _ segments: [MenuBarStatusSegment],
        presentationStyles: [SpillMenuBarStatusItem: MenuBarStatusPresentationStyle],
        compactMode: Bool
    ) -> [MenuBarStatusSegment] {
        segments.map { segment in
            if let item = menuBarStatusItem(for: segment.kind),
               presentationStyles[item] == .chart
            {
                return segment.chartMenuBarSegment()
            }

            return compactMode ? segment.valueOnlyMenuBarSegment() : segment
        }
    }

    private static func menuBarStatusItem(
        for kind: MenuBarStatusSegment.Kind
    ) -> SpillMenuBarStatusItem? {
        switch kind {
        case .cpu:
            return .cpu
        case .memory:
            return .memory
        case .network:
            return .network
        case .trigger, .caffeine, .ai, .sleepGuard:
            return nil
        }
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
            let groupedSegments = Self.splitStatusSegments(statusSegments)
            return (
                main: Self.orderedSegments(trigger: trigger, statusSegments: [], caffeineSegment: caffeineSegment),
                system: groupedSegments.system,
                ai: groupedSegments.ai
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

    static func splitStatusSegments(
        _ segments: [MenuBarStatusSegment]
    ) -> (system: [MenuBarStatusSegment], ai: [MenuBarStatusSegment]) {
        (
            system: segments.filter {
                $0.kind == .cpu || $0.kind == .memory || $0.kind == .network
            },
            ai: segments.filter { $0.kind == .ai }
        )
    }
}
