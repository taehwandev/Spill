import Foundation

enum SpillAppLanguage: String, CaseIterable, Identifiable {
    case automatic
    case english
    case korean
    case japanese

    static let defaultsKey = "appLanguage"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .english:
            return "English"
        case .korean:
            return "한국어"
        case .japanese:
            return "日本語"
        }
    }

    var detail: String {
        switch self {
        case .automatic:
            return "Follow macOS language"
        case .english:
            return "Use English"
        case .korean:
            return "한국어 사용"
        case .japanese:
            return "日本語を使用"
        }
    }

    var languageCode: String? {
        switch self {
        case .automatic:
            return nil
        case .english:
            return "en"
        case .korean:
            return "ko"
        case .japanese:
            return "ja"
        }
    }

    static func normalized(rawValue: String?) -> Self {
        guard let rawValue, let language = Self(rawValue: rawValue) else {
            return .automatic
        }
        return language
    }

    static func persisted(defaults: UserDefaults = .standard) -> Self {
        normalized(rawValue: defaults.string(forKey: defaultsKey))
    }
}
