import Foundation

/// The tabs of the Preferences window. Raw values are the identifiers other processes and smoke
/// runs already send to open a specific tab, so they must stay as they are.
enum PreferencesTab: String, CaseIterable, Identifiable {
    case general
    case menuBar = "menubar"
    case tokenMetering = "tokens"
    case windowManagement = "windows"
    case statusCaffeine = "status_caffeine"
    case developer

    var id: String { rawValue }

    /// Developer options exist only in builds that enable them.
    var isAvailable: Bool {
        self != .developer || SpillBuildOptions.developerOptionsEnabled
    }

    static var available: [PreferencesTab] {
        allCases.filter(\.isAvailable)
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .menuBar: return "menubar.rectangle"
        case .tokenMetering: return "chart.bar.xaxis"
        case .windowManagement: return "macwindow"
        case .statusCaffeine: return "cup.and.saucer.fill"
        case .developer: return "hammer.fill"
        }
    }

    var sidebarTitleKey: PreferencesTextKey {
        switch self {
        case .general: return .general
        case .menuBar: return .menuBar
        case .tokenMetering: return .tokenMetering
        case .windowManagement: return .windowManagement
        case .statusCaffeine: return .statusAndCaffeine
        case .developer: return .developerOptions
        }
    }

    var pageTitleKey: PreferencesTextKey {
        self == .menuBar ? .menuBarAndNotch : sidebarTitleKey
    }
}
