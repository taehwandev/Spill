import AppKit

@MainActor
final class StatusItemController: NSObject {
    let defaultLength: CGFloat = 26
    static let inactiveMaximumStatusItemLength: CGFloat = 190
    static let activeSleepGuardMaximumStatusItemLength: CGFloat = 176
    static let expandedStatusItemScreenRatio: CGFloat = 0.18
    static let expandedMaximumStatusItemLength: CGFloat = 320
    let settings: SpillSettings
    let statusStore: SystemStatusStore
    let sleepGuard: SleepGuardController
    let hiddenItemCountProvider: () -> Int
    let aiTokenCountProvider: () -> (daily: Int, total: Int)
    let aiServerHealthProvider: () -> CloudServiceHealth?
    let toggleAction: () -> Void
    let refreshAction: () -> Void
    let preferencesAction: () -> Void
    let tokenDashboardAction: () -> Void
    let updateAction: () -> Void
    let quitAction: () -> Void
    let triggerItem: NSStatusItem
    let systemItem: NSStatusItem
    let aiItem: NSStatusItem
    var isSpillBarVisible = false
    var pressedMouseButtonsProvider: () -> Int = { NSEvent.pressedMouseButtons }
    var mouseLocationProvider: () -> NSPoint = { NSEvent.mouseLocation }
    var isDeferredRefreshScheduled = false
    var mainStatusContentView: MenuBarStatusContentView?
    var systemStatusContentView: MenuBarStatusContentView?
    var aiStatusContentView: MenuBarStatusContentView?
    var currentMainSegments: [MenuBarStatusSegment] = []
    var currentSystemSegments: [MenuBarStatusSegment] = []
    var currentAISegments: [MenuBarStatusSegment] = []
    var currentLayoutStyle: MenuBarStatusLayoutStyle = .inline
    var currentMenuBarStatusFontSize: CGFloat = MenuBarStatusContentView.defaultTextFontSize
    var currentMenuBarStatusTextBold = false
    var currentMenuBarStatusCompactMode = false
    var currentMenuBarStatusSplitGroups = false
    var currentMainGroupsMainCaffeine = false

    init(
        settings: SpillSettings,
        statusStore: SystemStatusStore,
        sleepGuard: SleepGuardController,
        hiddenItemCountProvider: @escaping () -> Int,
        aiTokenCountProvider: @escaping () -> (daily: Int, total: Int),
        aiServerHealthProvider: @escaping () -> CloudServiceHealth? = { nil },
        toggleAction: @escaping () -> Void,
        refreshAction: @escaping () -> Void,
        preferencesAction: @escaping () -> Void,
        tokenDashboardAction: @escaping () -> Void,
        updateAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        self.settings = settings
        self.statusStore = statusStore
        self.sleepGuard = sleepGuard
        self.hiddenItemCountProvider = hiddenItemCountProvider
        self.aiTokenCountProvider = aiTokenCountProvider
        self.aiServerHealthProvider = aiServerHealthProvider
        self.toggleAction = toggleAction
        self.refreshAction = refreshAction
        self.preferencesAction = preferencesAction
        self.tokenDashboardAction = tokenDashboardAction
        self.updateAction = updateAction
        self.quitAction = quitAction

        triggerItem = NSStatusBar.system.statusItem(withLength: defaultLength)
        systemItem = NSStatusBar.system.statusItem(withLength: defaultLength)
        aiItem = NSStatusBar.system.statusItem(withLength: defaultLength)

        super.init()

        triggerItem.autosaveName = "dev.spill.status-trigger"
        systemItem.autosaveName = "dev.spill.status-system"
        aiItem.autosaveName = "dev.spill.status-ai"

        configureStatusButtons()
        refresh(isSpillBarVisible: false)
    }
}
