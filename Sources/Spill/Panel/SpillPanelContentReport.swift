import Foundation

struct SpillPanelContentReport: Equatable {
    let isVisible: Bool
    let statusModuleIDs: [String]
    let statusDetailRowCount: Int
    let aiStatusCount: Int
    let aiDetailRowCount: Int
    let windowActionCount: Int
    let footerItemCount: Int
    let showsPowerFooter: Bool

    var isValid: Bool {
        isVisible
            && hasConsistentStatusContent
            && hasConsistentAIContent
            && hasFooterContent
    }

    var logLine: String {
        [
            "visible=\(isVisible)",
            "statusModules=\(formattedStatusModules)",
            "statusRows=\(statusDetailRowCount)",
            "aiStatuses=\(aiStatusCount)",
            "aiRows=\(aiDetailRowCount)",
            "windowActions=\(windowActionCount)",
            "footerItems=\(footerItemCount)",
            "powerFooter=\(showsPowerFooter)",
            "statusContent=\(hasConsistentStatusContent)",
            "aiContent=\(hasConsistentAIContent)",
            "footerContent=\(hasFooterContent)"
        ].joined(separator: " ")
    }

    private var hasConsistentStatusContent: Bool {
        statusModuleIDs.isEmpty || statusDetailRowCount >= statusModuleIDs.count
    }

    private var hasConsistentAIContent: Bool {
        (0 ... LocalAIToolKind.allCases.count).contains(aiStatusCount)
            && aiDetailRowCount >= aiStatusCount
    }

    private var hasFooterContent: Bool {
        footerItemCount >= 3
    }

    private var formattedStatusModules: String {
        statusModuleIDs.isEmpty ? "none" : statusModuleIDs.joined(separator: ",")
    }
}
