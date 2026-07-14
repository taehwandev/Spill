import Foundation

enum MenuBarTokenDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case daily
    case total
    case dailyAndTotal
    case cycle

    var id: String { rawValue }

    var title: String {
        title(appLanguage: .persisted())
    }

    func title(appLanguage: SpillAppLanguage) -> String {
        switch self {
        case .daily:
            return AppL10n.text(.menuBarTokenDisplayModeDaily, appLanguage: appLanguage)
        case .total:
            return AppL10n.text(.menuBarTokenDisplayModeTotal, appLanguage: appLanguage)
        case .dailyAndTotal:
            return AppL10n.text(.menuBarTokenDisplayModeDailyAndTotal, appLanguage: appLanguage)
        case .cycle:
            return AppL10n.text(.menuBarTokenDisplayModeCycle, appLanguage: appLanguage)
        }
    }
}
