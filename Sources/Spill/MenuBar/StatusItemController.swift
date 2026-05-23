import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let defaultLength: CGFloat = 26
    private static let inactiveMaximumStatusItemLength: CGFloat = 190
    private static let activeSleepGuardMaximumStatusItemLength: CGFloat = 176
    private static let expandedStatusItemScreenRatio: CGFloat = 0.18
    private static let expandedMaximumStatusItemLength: CGFloat = 320
    private let settings: SpillSettings
    private let statusStore: SystemStatusStore
    private let sleepGuard: SleepGuardController
    private let hiddenItemCountProvider: () -> Int
    private let toggleAction: () -> Void
    private let refreshAction: () -> Void
    private let preferencesAction: () -> Void
    private let updateAction: () -> Void
    private let quitAction: () -> Void
    private let triggerItem: NSStatusItem
    private var isSpillBarVisible = false
    private var statusContentView: MenuBarStatusContentView?
    private var currentSegments: [MenuBarStatusSegment] = []
    private var currentLayoutStyle: MenuBarStatusLayoutStyle = .inline

    init(
        settings: SpillSettings,
        statusStore: SystemStatusStore,
        sleepGuard: SleepGuardController,
        hiddenItemCountProvider: @escaping () -> Int,
        toggleAction: @escaping () -> Void,
        refreshAction: @escaping () -> Void,
        preferencesAction: @escaping () -> Void,
        updateAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        self.settings = settings
        self.statusStore = statusStore
        self.sleepGuard = sleepGuard
        self.hiddenItemCountProvider = hiddenItemCountProvider
        self.toggleAction = toggleAction
        self.refreshAction = refreshAction
        self.preferencesAction = preferencesAction
        self.updateAction = updateAction
        self.quitAction = quitAction

        triggerItem = NSStatusBar.system.statusItem(withLength: defaultLength)

        super.init()

        triggerItem.autosaveName = "dev.spill.status-trigger"

        configureTriggerButton()
        refresh(isSpillBarVisible: false)
    }

    func refresh(isSpillBarVisible: Bool? = nil) {
        if let isSpillBarVisible {
            self.isSpillBarVisible = isSpillBarVisible
        }

        guard let button = triggerItem.button else {
            return
        }

        let hiddenCount = hiddenItemCountProvider()
        let summary = MenuBarStatusSummary.make(
            enabledItems: settings.enabledMenuBarStatusItems,
            cpu: statusStore.cpu,
            memory: statusStore.memory,
            displayStyle: settings.menuBarStatusDisplayStyle,
            precision: settings.menuBarStatusPrecision,
            highlightThreshold: settings.menuBarStatusHighlightThreshold
        )
        let performanceEffect = menuBarPerformanceEffect
        let sleepGuardSegment = sleepGuardMenuBarSegment
        let layoutStyle = settings.menuBarStatusLayoutStyle
        let segments = Self.visibleSegments(
            trigger: triggerSegment(performanceEffect: performanceEffect),
            statusSegments: summary.segments,
            caffeineSegment: sleepGuardSegment,
            maximumWidth: maximumStatusItemLength,
            layoutStyle: layoutStyle
        )
        let segmentsChanged = segments != currentSegments
        let layoutChanged = layoutStyle != currentLayoutStyle
        currentSegments = segments
        currentLayoutStyle = layoutStyle
        let statusTooltip = statusTooltip(
            summary: summary,
            sleepGuardSegment: sleepGuardSegment,
            performanceEffect: performanceEffect
        )
        triggerItem.isVisible = true
        triggerItem.length = MenuBarStatusContentView.preferredWidth(for: segments, layoutStyle: layoutStyle)
        configureAppearance(
            for: button,
            segments: segments,
            statusTooltip: statusTooltip,
            layoutStyle: layoutStyle,
            rebuildsContentView: segmentsChanged || layoutChanged
        )
        button.state = self.isSpillBarVisible ? .on : .off
        button.toolTip = tooltip(
            statusTooltip: statusTooltip,
            hiddenCount: hiddenCount,
            isSpillBarVisible: self.isSpillBarVisible
        )
    }

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
        layoutStyle: MenuBarStatusLayoutStyle = .inline
    ) -> [MenuBarStatusSegment] {
        let requestedSegments = orderedSegments(
            trigger: trigger,
            statusSegments: statusSegments,
            caffeineSegment: caffeineSegment
        )
        guard MenuBarStatusContentView.preferredWidth(
            for: requestedSegments,
            layoutStyle: layoutStyle
        ) > maximumWidth else {
            return requestedSegments
        }

        let compactCaffeineSegment = caffeineSegment?.withoutMenuBarValue()
        var visibleStatusSegments = statusSegments.map { $0.valueOnlyMenuBarSegment() }
        var fittedSegments = orderedSegments(
            trigger: trigger,
            statusSegments: visibleStatusSegments,
            caffeineSegment: compactCaffeineSegment
        )

        while !visibleStatusSegments.isEmpty,
              MenuBarStatusContentView.preferredWidth(
                  for: fittedSegments,
                  layoutStyle: layoutStyle
              ) > maximumWidth {
            visibleStatusSegments.removeLast()
            fittedSegments = orderedSegments(
                trigger: trigger,
                statusSegments: visibleStatusSegments,
                caffeineSegment: compactCaffeineSegment
            )
        }

        if MenuBarStatusContentView.preferredWidth(
            for: fittedSegments,
            layoutStyle: layoutStyle
        ) <= maximumWidth {
            return fittedSegments
        }

        let essentialSegments = orderedSegments(
            trigger: trigger,
            statusSegments: [],
            caffeineSegment: compactCaffeineSegment
        )
        guard MenuBarStatusContentView.preferredWidth(
            for: essentialSegments,
            layoutStyle: layoutStyle
        ) > maximumWidth else {
            return essentialSegments
        }

        return [trigger]
    }

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

    private var maximumStatusItemLength: CGFloat {
        Self.maximumStatusItemLength(
            screenWidth: statusItemScreenWidth,
            isSleepGuardActive: sleepGuard.isActive
        )
    }

    private var statusItemScreenWidth: CGFloat? {
        if let screenWidth = triggerItem.button?.window?.screen?.visibleFrame.width,
           screenWidth > 0 {
            return screenWidth
        }

        return NSScreen.main?.visibleFrame.width
    }

    private func configureTriggerButton() {
        guard let button = triggerItem.button else {
            return
        }

        triggerItem.isVisible = true
        triggerItem.length = defaultLength
        configureIconAppearance(for: button)
        button.target = self
        button.action = #selector(statusButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureAppearance(
        for button: NSStatusBarButton,
        segments: [MenuBarStatusSegment],
        statusTooltip: String,
        layoutStyle: MenuBarStatusLayoutStyle,
        rebuildsContentView: Bool
    ) {
        button.image = nil
        button.imagePosition = .noImage
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.isBordered = false

        if !segments.isEmpty {
            installStatusContentView(
                on: button,
                segments: segments,
                layoutStyle: layoutStyle,
                rebuildsContentView: rebuildsContentView
            )
            button.setAccessibilityLabel(statusTooltip.isEmpty ? "Spill" : statusTooltip)
            return
        }

        configureIconAppearance(for: button)
    }

    private func configureIconAppearance(for button: NSStatusBarButton) {
        removeStatusContentView()
        button.image = nil
        button.imagePosition = .noImage
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.isBordered = false

        let symbolName = isSpillBarVisible ? "drop.circle.fill" : "drop.fill"
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Spill")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel("Spill")
            return
        }

        button.image = nil
        button.imagePosition = .noImage
        button.title = "Spill"
        button.attributedTitle = attributedTitle("Spill", fontSize: 12)
        button.setAccessibilityLabel("Spill")
    }

    private func installStatusContentView(
        on button: NSStatusBarButton,
        segments: [MenuBarStatusSegment],
        layoutStyle: MenuBarStatusLayoutStyle,
        rebuildsContentView: Bool
    ) {
        guard rebuildsContentView || statusContentView == nil else {
            return
        }

        removeStatusContentView()

        let contentView = MenuBarStatusContentView(segments: segments, layoutStyle: layoutStyle)
        button.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: button.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        statusContentView = contentView
    }

    private func removeStatusContentView() {
        statusContentView?.removeFromSuperview()
        statusContentView = nil
    }

    private func attributedTitle(_ title: String, fontSize: CGFloat) -> NSAttributedString {
        NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func tooltip(
        statusTooltip: String,
        hiddenCount: Int,
        isSpillBarVisible: Bool
    ) -> String {
        var parts: [String] = []

        if !statusTooltip.isEmpty {
            parts.append(statusTooltip)
        }

        parts.append(isSpillBarVisible ? "Hide Spill Bar" : "Show Spill Bar")

        if hiddenCount > 0 {
            parts.append("\(hiddenCount) menu bar item(s)")
        }

        return parts.joined(separator: "\n")
    }

    private var sleepGuardMenuBarSegment: MenuBarStatusSegment? {
        return SleepGuardMenuBarSegmentFactory.make(
            isEnabled: settings.isMenuBarStatusItemEnabled(.caffeine),
            isActive: sleepGuard.isActive,
            remainingLabel: sleepGuard.remainingLabel,
            showsRemainingInMenuBar: settings.sleepGuardShowsRemainingInMenuBar
        )
    }

    private var menuBarPerformanceEffect: MenuBarPerformanceEffect {
        MenuBarPerformanceEffect.make(
            cpu: statusStore.cpu,
            memory: statusStore.memory,
            network: statusStore.network,
            power: statusStore.power
        )
    }

    private func triggerSegment(performanceEffect: MenuBarPerformanceEffect) -> MenuBarStatusSegment {
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

    private func statusTooltip(
        summary: MenuBarStatusSummary,
        sleepGuardSegment: MenuBarStatusSegment?,
        performanceEffect: MenuBarPerformanceEffect
    ) -> String {
        var parts: [String] = []

        if settings.menuBarTriggerIconStyle.usesPerformanceEffect {
            parts.append("Trigger load: \(performanceEffect.tooltipText)")
        }

        if sleepGuardSegment != nil {
            if !sleepGuard.isActive {
                parts.append("Caffeine chip: click to start for \(settings.sleepGuardDefaultDuration.menuTitle)")
            } else if sleepGuard.activeDuration?.isIndefinite == true {
                parts.append("Caffeine chip: on until stopped - click to stop")
            } else {
                parts.append("Caffeine chip: \(sleepGuard.remainingLabel) remaining - click to stop")
            }
        }

        if !summary.title.isEmpty {
            parts.append(summary.tooltip)
        }

        return parts.joined(separator: " | ")
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let shouldShowMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true

        if shouldShowMenu {
            showMenu(for: sender, event: event)
        } else if isCaffeineSegmentClick(sender: sender, event: event) {
            toggleCaffeineFromStatusItem()
        } else {
            toggleAction()
        }
    }

    private func isCaffeineSegmentClick(sender: NSStatusBarButton, event: NSEvent?) -> Bool {
        guard let event else {
            return false
        }

        let point = sender.convert(event.locationInWindow, from: nil)
        return MenuBarStatusContentView.segmentKind(
            at: point,
            in: currentSegments,
            layoutStyle: currentLayoutStyle
        ) == .caffeine
    }

    private func toggleCaffeineFromStatusItem() {
        sleepGuard.toggle(
            duration: settings.sleepGuardDefaultDuration,
            keepDisplayAwake: settings.sleepGuardKeepsDisplayAwake
        )
        refresh()
    }

    @objc private func toggleFromMenu() {
        toggleAction()
    }

    @objc private func showPreferencesFromMenu() {
        preferencesAction()
    }

    @objc private func refreshFromMenu() {
        refreshAction()
    }

    @objc private func checkForUpdatesFromMenu() {
        updateAction()
    }

    @objc private func quitFromMenu() {
        quitAction()
    }

    private func showMenu(for button: NSStatusBarButton, event: NSEvent?) {
        let menu = NSMenu()
        let toggleTitle = isSpillBarVisible ? "Hide Spill Bar" : "Show Spill Bar"

        menu.addItem(menuItem(title: toggleTitle, action: #selector(toggleFromMenu), keyEquivalent: ""))
        menu.addItem(disabledMenuItem(title: "Shortcut: \(WindowActionShortcutModifier.standard.title) + Space"))
        menu.addItem(menuItem(title: "Refresh Menu Bar Items", action: #selector(refreshFromMenu), keyEquivalent: "r"))
        menu.addItem(menuItem(title: "Check for Updates...", action: #selector(checkForUpdatesFromMenu), keyEquivalent: ""))
        menu.addItem(menuItem(title: "Preferences...", action: #selector(showPreferencesFromMenu), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit Spill", action: #selector(quitFromMenu), keyEquivalent: "q"))

        if let event {
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        }
    }

    private func menuItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func disabledMenuItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

enum SleepGuardMenuBarSegmentFactory {
    static func make(
        isEnabled: Bool,
        isActive: Bool,
        remainingLabel: String,
        showsRemainingInMenuBar: Bool
    ) -> MenuBarStatusSegment? {
        guard isEnabled else {
            return nil
        }

        let displayText = isActive && showsRemainingInMenuBar ? remainingLabel : ""

        return MenuBarStatusSegment(
            kind: .caffeine,
            title: "Caffeine",
            shortTitle: "CAF",
            value: displayText,
            displayText: displayText,
            usageRatio: 0,
            state: isActive ? .active : .unavailable,
            symbolName: isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        )
    }
}
