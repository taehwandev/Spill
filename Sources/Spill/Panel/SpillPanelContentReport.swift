import Foundation

struct SpillPanelContentReport: Equatable {
    let isVisible: Bool
    let panelState: SpillPanelState
    let statusModuleIDs: [String]
    let statusDetailRowCount: Int
    let aiStatusCount: Int
    let aiDetailRowCount: Int
    let windowActionCount: Int
    let menuBarActionCount: Int
    let footerItemCount: Int
    let showsPowerFooter: Bool
    let showsCountBadge: Bool

    var isValid: Bool {
        isVisible
            && hasConsistentStatusContent
            && hasConsistentAIContent
            && hasActionSurface
            && hasFooterContent
    }

    var logLine: String {
        [
            "visible=\(isVisible)",
            "state=\(panelState.logName)",
            "statusModules=\(formattedStatusModules)",
            "statusRows=\(statusDetailRowCount)",
            "aiStatuses=\(aiStatusCount)",
            "aiRows=\(aiDetailRowCount)",
            "windowActions=\(windowActionCount)",
            "menuBarActions=\(menuBarActionCount)",
            "footerItems=\(footerItemCount)",
            "powerFooter=\(showsPowerFooter)",
            "countBadge=\(showsCountBadge)",
            "statusContent=\(hasConsistentStatusContent)",
            "aiContent=\(hasConsistentAIContent)",
            "actionSurface=\(hasActionSurface)",
            "footerContent=\(hasFooterContent)"
        ].joined(separator: " ")
    }

    private var hasConsistentStatusContent: Bool {
        statusModuleIDs.isEmpty || statusDetailRowCount >= statusModuleIDs.count
    }

    private var hasConsistentAIContent: Bool {
        aiStatusCount == LocalAIToolKind.allCases.count
            && aiDetailRowCount >= aiStatusCount
    }

    private var hasActionSurface: Bool {
        panelState != .ready || windowActionCount + menuBarActionCount > 0
    }

    private var hasFooterContent: Bool {
        footerItemCount >= 3
    }

    private var formattedStatusModules: String {
        statusModuleIDs.isEmpty ? "none" : statusModuleIDs.joined(separator: ",")
    }
}
