import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let defaultLength: CGFloat = 26
    private let settings: SpillSettings
    private let statusStore: SystemStatusStore
    private let hiddenItemCountProvider: () -> Int
    private let toggleAction: () -> Void
    private let refreshAction: () -> Void
    private let preferencesAction: () -> Void
    private let quitAction: () -> Void
    private let triggerItem: NSStatusItem
    private var isSpillBarVisible = false
    private var statusContentView: MenuBarStatusContentView?

    init(
        settings: SpillSettings,
        statusStore: SystemStatusStore,
        hiddenItemCountProvider: @escaping () -> Int,
        toggleAction: @escaping () -> Void,
        refreshAction: @escaping () -> Void,
        preferencesAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        self.settings = settings
        self.statusStore = statusStore
        self.hiddenItemCountProvider = hiddenItemCountProvider
        self.toggleAction = toggleAction
        self.refreshAction = refreshAction
        self.preferencesAction = preferencesAction
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
        triggerItem.isVisible = true
        triggerItem.length = summary.segments.isEmpty ? defaultLength : MenuBarStatusContentView.preferredWidth(for: summary.segments)
        configureAppearance(for: button, summary: summary)
        button.state = self.isSpillBarVisible ? .on : .off
        button.toolTip = tooltip(
            summary: summary,
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

    private func configureAppearance(for button: NSStatusBarButton, summary: MenuBarStatusSummary) {
        button.image = nil
        button.imagePosition = .noImage
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.isBordered = false

        if !summary.segments.isEmpty {
            installStatusContentView(on: button, segments: summary.segments)
            button.setAccessibilityLabel(summary.tooltip)
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

    private func installStatusContentView(on button: NSStatusBarButton, segments: [MenuBarStatusSegment]) {
        removeStatusContentView()

        let contentView = MenuBarStatusContentView(segments: segments)
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
        summary: MenuBarStatusSummary,
        hiddenCount: Int,
        isSpillBarVisible: Bool
    ) -> String {
        var parts: [String] = []

        if !summary.title.isEmpty {
            parts.append(summary.tooltip)
        }

        parts.append(isSpillBarVisible ? "Hide Spill Bar" : "Show Spill Bar")

        if hiddenCount > 0 {
            parts.append("\(hiddenCount) menu bar item(s)")
        }

        return parts.joined(separator: "\n")
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let shouldShowMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true

        if shouldShowMenu {
            showMenu()
        } else {
            toggleAction()
        }
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

    @objc private func quitFromMenu() {
        quitAction()
    }

    private func showMenu() {
        let menu = NSMenu()
        let toggleTitle = isSpillBarVisible ? "Hide Spill Bar" : "Show Spill Bar"

        menu.addItem(menuItem(title: toggleTitle, action: #selector(toggleFromMenu), keyEquivalent: ""))
        menu.addItem(disabledMenuItem(title: "Shortcut: Control + Option + Space"))
        menu.addItem(menuItem(title: "Refresh Menu Bar Items", action: #selector(refreshFromMenu), keyEquivalent: "r"))
        menu.addItem(menuItem(title: "Preferences...", action: #selector(showPreferencesFromMenu), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit Spill", action: #selector(quitFromMenu), keyEquivalent: "q"))

        triggerItem.menu = menu
        triggerItem.button?.performClick(nil)
        triggerItem.menu = nil
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
