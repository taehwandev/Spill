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

        let clickedSegment = clickedSegmentKind(
            sender: sender,
            event: event,
            segments: currentMainSegments
        )
        if clickedSegment == .caffeine {
            toggleCaffeineFromStatusItem()
        } else if clickedSegment == .ai {
            tokenDashboardAction()
        } else {
            toggleAction()
        }
    }

    @objc func systemStatusButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let shouldShowMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true

        if shouldShowMenu {
            showMenu(for: sender, event: event)
        } else {
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

    func clickedSegmentKind(
        sender: NSStatusBarButton,
        event: NSEvent?,
        segments: [MenuBarStatusSegment]
    ) -> MenuBarStatusSegment.Kind? {
        guard let event else {
            return nil
        }

        let point = sender.convert(event.locationInWindow, from: nil)
        return MenuBarStatusContentView.segmentKind(
            at: point,
            in: segments,
            layoutStyle: currentLayoutStyle,
            textFontSize: currentMenuBarStatusFontSize,
            textIsBold: currentMenuBarStatusTextBold,
            groupsMainCaffeine: currentMainGroupsMainCaffeine
        )
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
