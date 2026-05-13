import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let defaultLength: CGFloat = 26
    private let hiddenItemCountProvider: () -> Int
    private let toggleAction: () -> Void
    private let refreshAction: () -> Void
    private let preferencesAction: () -> Void
    private let quitAction: () -> Void
    private let triggerItem: NSStatusItem
    private var isSpillBarVisible = false

    init(
        settings: SpillSettings,
        hiddenItemCountProvider: @escaping () -> Int,
        toggleAction: @escaping () -> Void,
        refreshAction: @escaping () -> Void,
        preferencesAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
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
        triggerItem.isVisible = true
        triggerItem.length = defaultLength
        configureAppearance(for: button)
        button.state = self.isSpillBarVisible ? .on : .off
        button.toolTip = self.isSpillBarVisible
            ? "Hide Spill Bar"
            : hiddenCount > 0 ? "Show \(hiddenCount) menu bar item(s)" : "Show Spill Bar"
    }

    private func configureTriggerButton() {
        guard let button = triggerItem.button else {
            return
        }

        triggerItem.isVisible = true
        triggerItem.length = defaultLength
        configureAppearance(for: button)
        button.target = self
        button.action = #selector(statusButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureAppearance(for button: NSStatusBarButton) {
        button.image = nil
        button.imagePosition = .noImage
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.isBordered = false

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        if let image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Spill")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            return
        }

        button.image = nil
        button.imagePosition = .noImage
        button.title = "Spill"
        button.attributedTitle = attributedTitle("Spill", fontSize: 12)
    }

    private func attributedTitle(_ title: String, fontSize: CGFloat) -> NSAttributedString {
        NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
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
