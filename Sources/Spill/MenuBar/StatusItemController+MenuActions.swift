import AppKit

extension StatusItemController {
    func tooltip(
        statusTooltip: String,
        hiddenCount: Int,
        isSpillBarVisible: Bool
    ) -> String {
        var parts: [String] = []

        if !statusTooltip.isEmpty {
            parts.append(statusTooltip)
        }

        parts.append(isSpillBarVisible
            ? AppL10n.text(.hideSpillPanel, appLanguage: settings.appLanguage)
            : AppL10n.text(.showSpillPanel, appLanguage: settings.appLanguage)
        )

        if hiddenCount > 0 {
            parts.append(AppL10n.itemCount(hiddenCount, appLanguage: settings.appLanguage))
        }

        return parts.joined(separator: "\n")
    }

    var sleepGuardMenuBarSegment: MenuBarStatusSegment? {
        return SleepGuardMenuBarSegmentFactory.make(
            isEnabled: settings.isMenuBarStatusItemEnabled(.caffeine),
            isActive: sleepGuard.isActive,
            remainingLabel: sleepGuard.remainingLabel,
            showsRemainingInMenuBar: settings.sleepGuardShowsRemainingInMenuBar
        )
    }

    var menuBarPerformanceEffect: MenuBarPerformanceEffect {
        MenuBarPerformanceEffect.make(
            cpu: statusStore.cpu,
            memory: statusStore.memory,
            network: statusStore.network,
            power: statusStore.power
        )
    }

    func triggerSegment(performanceEffect: MenuBarPerformanceEffect) -> MenuBarStatusSegment {
        let triggerIconStyle = settings.menuBarTriggerIconStyle
        let triggerState = isSpillBarVisible
            ? SpillStatusState.active
            : (triggerIconStyle.usesPerformanceEffect ? performanceEffect.state : .normal)

        return MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: triggerIconStyle.usesPerformanceEffect ? performanceEffect.usageRatio : 0,
            state: triggerState,
            symbolName: triggerIconStyle.symbolName(isActive: isSpillBarVisible),
            visualStyle: .trigger(triggerIconStyle),
            animates: settings.useSpillAnimation && triggerIconStyle.animates
        )
    }

    func statusTooltip(
        summary: MenuBarStatusSummary,
        sleepGuardSegment: MenuBarStatusSegment?,
        performanceEffect: MenuBarPerformanceEffect
    ) -> String {
        var parts: [String] = []

        if settings.menuBarTriggerIconStyle.usesPerformanceEffect {
            parts.append("\(AppL10n.text(.triggerLoad, appLanguage: settings.appLanguage)): \(performanceEffect.tooltipText)")
        }

        if sleepGuardSegment != nil {
            if !sleepGuard.isActive {
                let duration = AppL10n.sleepDurationTitle(settings.sleepGuardDefaultDuration, appLanguage: settings.appLanguage)
                parts.append("\(AppL10n.text(.caffeineChipStart, appLanguage: settings.appLanguage)) \(duration)")
            } else if sleepGuard.activeDuration?.isIndefinite == true {
                let detail = sleepGuard.keepsDisplayAwake
                    ? AppL10n.text(.caffeineOnUntilStopped, appLanguage: settings.appLanguage)
                    : AppL10n.text(.caffeineOnUntilStoppedDisplayMaySleep, appLanguage: settings.appLanguage)
                parts.append("\(AppL10n.text(.caffeine, appLanguage: settings.appLanguage)): \(detail) - \(AppL10n.text(.caffeineChipStop, appLanguage: settings.appLanguage))")
            } else {
                let detail = sleepGuard.keepsDisplayAwake
                    ? String(format: AppL10n.text(.caffeineRemaining, appLanguage: settings.appLanguage), sleepGuard.remainingLabel)
                    : String(format: AppL10n.text(.caffeineRemainingDisplayMaySleep, appLanguage: settings.appLanguage), sleepGuard.remainingLabel)
                parts.append("\(AppL10n.text(.caffeine, appLanguage: settings.appLanguage)): \(detail) - \(AppL10n.text(.caffeineChipStop, appLanguage: settings.appLanguage))")
            }
        }

        if !summary.title.isEmpty {
            parts.append(summary.tooltip)
        }

        return parts.joined(separator: " | ")
    }

}

extension StatusItemController {
    func segmentTooltip(for segments: [MenuBarStatusSegment]) -> String {
        segments.map { segment in
            segment.value.isEmpty
                ? segment.title
                : "\(segment.title) \(segment.value)"
        }
        .joined(separator: " | ")
    }

    @objc func mainStatusButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let shouldShowMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true

        if shouldShowMenu {
            showMenu(for: sender, event: event)
            return
        }

        perform(
            clickedSegmentKind(sender: sender, event: event, contentView: mainStatusContentView)
        )
    }

    @objc func systemStatusButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let shouldShowMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true

        if shouldShowMenu {
            showMenu(for: sender, event: event)
            return
        }

        perform(
            clickedSegmentKind(sender: sender, event: event, contentView: systemStatusContentView)
        )
    }

    /// Chips that carry their own action run it; everything else falls back to the panel toggle.
    func perform(_ clickedSegment: MenuBarStatusSegment.Kind?) {
        switch clickedSegment {
        case .caffeine:
            toggleCaffeineFromStatusItem()
        case .ai:
            tokenDashboardAction()
        default:
            toggleAction()
        }
    }

    @objc func aiStatusButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let shouldShowMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true

        if shouldShowMenu {
            showMenu(for: sender, event: event)
        } else {
            tokenDashboardAction()
        }
    }

    /// Which chip the click landed on, resolved against the chips' real laid-out frames.
    ///
    /// The point comes from the global cursor position rather than the click event: the event's
    /// `locationInWindow` is relative to whichever window delivered it, and depending on that is
    /// what made every chip click collapse into one action when the menu bar changed. The event is
    /// only a fallback for clicks that arrive without a usable cursor position.
    func clickedSegmentKind(
        sender: NSStatusBarButton,
        event: NSEvent?,
        contentView: MenuBarStatusContentView?
    ) -> MenuBarStatusSegment.Kind? {
        guard let contentView else {
            return nil
        }

        guard let point = clickPoint(in: contentView, sender: sender, event: event) else {
            return nil
        }

        return contentView.segmentKind(atContentPoint: point)
    }

    private func clickPoint(
        in contentView: MenuBarStatusContentView,
        sender: NSStatusBarButton,
        event: NSEvent?
    ) -> NSPoint? {
        let windowPoint = Self.clickPointInWindow(
            mouseLocation: mouseLocationProvider(),
            statusWindowFrame: sender.window?.frame,
            eventLocationInWindow: event?.window == nil ? nil : event?.locationInWindow
        )
        return windowPoint.map { contentView.convert($0, from: nil) }
    }

    /// The click in the status item window's coordinates.
    ///
    /// The cursor position wins because it is independent of which window delivered the event, and
    /// it is only trusted while the cursor is still over the status item. Without either input
    /// there is no click position, and the caller must fall back to the item-wide action rather
    /// than guess a chip.
    static func clickPointInWindow(
        mouseLocation: NSPoint,
        statusWindowFrame: NSRect?,
        eventLocationInWindow: NSPoint?
    ) -> NSPoint? {
        if let statusWindowFrame, statusWindowFrame.contains(mouseLocation) {
            return NSPoint(
                x: mouseLocation.x - statusWindowFrame.minX,
                y: mouseLocation.y - statusWindowFrame.minY
            )
        }

        return eventLocationInWindow
    }

    func toggleCaffeineFromStatusItem() {
        sleepGuard.toggle(
            duration: settings.sleepGuardDefaultDuration,
            keepDisplayAwake: settings.sleepGuardKeepsDisplayAwake
        )
        refresh()
    }

    @objc func toggleFromMenu() {
        toggleAction()
    }

    @objc func showPreferencesFromMenu() {
        preferencesAction()
    }

    @objc func openTokenDashboardFromMenu() {
        tokenDashboardAction()
    }

}
