import SwiftUI

enum SpillStatusFontDesign: String, CaseIterable, Identifiable {
    case `default`
    case rounded
    case monospaced

    var id: String { rawValue }

    var title: String {
        title(appLanguage: .persisted())
    }

    func title(appLanguage: SpillAppLanguage) -> String {
        switch self {
        case .default: return PreferencesL10n.text(.fontDefault, appLanguage: appLanguage)
        case .rounded: return PreferencesL10n.text(.fontRounded, appLanguage: appLanguage)
        case .monospaced: return PreferencesL10n.text(.fontMono, appLanguage: appLanguage)
        }
    }

    var fontDesign: Font.Design {
        switch self {
        case .default: return .default
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        }
    }
}
