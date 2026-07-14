import Foundation

enum MenuBarStatusPresentationStyle: String, CaseIterable, Identifiable, Sendable {
    case text
    case chart

    var id: String {
        rawValue
    }

    func title(appLanguage: SpillAppLanguage) -> String {
        switch self {
        case .text:
            return PreferencesL10n.text(.text, appLanguage: appLanguage)
        case .chart:
            return PreferencesL10n.text(.chart, appLanguage: appLanguage)
        }
    }
}
