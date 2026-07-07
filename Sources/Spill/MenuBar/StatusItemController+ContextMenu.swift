import AppKit

extension StatusItemController {
    @objc func refreshFromMenu() {
        refreshAction()
    }

    @objc func checkForUpdatesFromMenu() {
        updateAction()
    }

    @objc func quitFromMenu() {
        quitAction()
    }

    func showMenu(for button: NSStatusBarButton, event: NSEvent?) {
        let menu = NSMenu()
        let toggleTitle = isSpillBarVisible
            ? AppL10n.text(.hideSpillPanel, appLanguage: settings.appLanguage)
            : AppL10n.text(.showSpillPanel, appLanguage: settings.appLanguage)

        menu.addItem(menuItem(title: toggleTitle, action: #selector(toggleFromMenu), keyEquivalent: ""))
        menu.addItem(disabledMenuItem(title: "\(AppL10n.text(.shortcut, appLanguage: settings.appLanguage)): \(WindowActionShortcutModifier.standard.title) + Space"))
        menu.addItem(.separator())
        menu.addItem(disabledMenuItem(title: AppL10n.text(.tokenMeteringLocalDashboard, appLanguage: settings.appLanguage)))
        menu.addItem(menuItem(title: AppL10n.text(.openLocalTokenDashboard, appLanguage: settings.appLanguage), action: #selector(openTokenDashboardFromMenu), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: AppL10n.text(.refreshMenuBarItems, appLanguage: settings.appLanguage), action: #selector(refreshFromMenu), keyEquivalent: "r"))
        menu.addItem(menuItem(title: AppL10n.text(.checkForUpdates, appLanguage: settings.appLanguage), action: #selector(checkForUpdatesFromMenu), keyEquivalent: ""))
        menu.addItem(menuItem(title: AppL10n.text(.preferences, appLanguage: settings.appLanguage), action: #selector(showPreferencesFromMenu), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: AppL10n.text(.quitSpill, appLanguage: settings.appLanguage), action: #selector(quitFromMenu), keyEquivalent: ""))

        if let event {
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        }
    }

    func menuItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    func disabledMenuItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
