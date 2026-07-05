import AppKit
import Foundation

enum PreferencesLegalLink: String, CaseIterable, Identifiable {
    case privacy
    case terms
    case syncData

    var id: String {
        rawValue
    }

    var url: URL {
        switch self {
        case .privacy, .syncData:
            return URL(string: "https://spill.thdev.app/privacy")!
        case .terms:
            return URL(string: "https://spill.thdev.app/terms")!
        }
    }

    var symbolName: String {
        switch self {
        case .privacy:
            return "hand.raised.fill"
        case .terms:
            return "doc.text.fill"
        case .syncData:
            return "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    func title(appLanguage: SpillAppLanguage) -> String {
        switch self {
        case .privacy:
            return PreferencesLegalL10n.text(.privacyPolicy, appLanguage: appLanguage)
        case .terms:
            return PreferencesLegalL10n.text(.termsOfService, appLanguage: appLanguage)
        case .syncData:
            return PreferencesLegalL10n.text(.syncDataHandling, appLanguage: appLanguage)
        }
    }

    func open(source: String) {
        SpillTelemetry.shared.track(
            "legal_link_clicked",
            props: ["source": source, "link": rawValue]
        )
        NSWorkspace.shared.open(url)
    }
}
