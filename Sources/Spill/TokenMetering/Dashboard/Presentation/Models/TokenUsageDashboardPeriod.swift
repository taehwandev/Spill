import Foundation

enum TokenUsageDashboardPeriod: String, CaseIterable, Equatable {
    case today
    case sevenDays
    case thirtyDays
    case all

    var title: String {
        title(language: .current())
    }

    func title(language: TokenMeteringLanguage) -> String {
        switch self {
        case .today:
            return TokenMeteringL10n.text(.periodToday, language: language)
        case .sevenDays:
            return TokenMeteringL10n.text(.periodSevenDays, language: language)
        case .thirtyDays:
            return TokenMeteringL10n.text(.periodThirtyDays, language: language)
        case .all:
            return TokenMeteringL10n.text(.periodAll, language: language)
        }
    }
}
