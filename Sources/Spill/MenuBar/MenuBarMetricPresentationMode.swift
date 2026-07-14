import Foundation

enum MenuBarMetricPresentationMode: String, CaseIterable, Identifiable, Sendable {
    case off
    case text
    case chart

    var id: String {
        rawValue
    }

    var presentationStyle: MenuBarStatusPresentationStyle? {
        switch self {
        case .off:
            return nil
        case .text:
            return .text
        case .chart:
            return .chart
        }
    }

    func title(appLanguage: SpillAppLanguage) -> String {
        switch self {
        case .off:
            return PreferencesL10n.text(.off, appLanguage: appLanguage)
        case .text:
            return PreferencesL10n.text(.text, appLanguage: appLanguage)
        case .chart:
            return PreferencesL10n.text(.chart, appLanguage: appLanguage)
        }
    }
}
