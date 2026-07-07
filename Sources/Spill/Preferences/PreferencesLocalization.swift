import Foundation

enum PreferencesL10n {
    static func text(
        _ key: PreferencesTextKey,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return table[language]?[key] ?? table[.english]?[key] ?? key.rawValue
    }
}

extension PreferencesL10n {
    static func languageDetail(
        _ selectedLanguage: SpillAppLanguage,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        switch (language, selectedLanguage) {
        case (.english, .automatic):
            return "Follow macOS language"
        case (.english, .english):
            return "Use English"
        case (.english, .korean):
            return "Use Korean"
        case (.english, .japanese):
            return "Use Japanese"
        case (.korean, .automatic):
            return "macOS 언어를 따릅니다"
        case (.korean, .english):
            return "영어 사용"
        case (.korean, .korean):
            return "한국어 사용"
        case (.korean, .japanese):
            return "일본어 사용"
        case (.japanese, .automatic):
            return "macOS の言語に合わせる"
        case (.japanese, .english):
            return "英語を使用"
        case (.japanese, .korean):
            return "韓国語を使用"
        case (.japanese, .japanese):
            return "日本語を使用"
        }
    }

    static func itemCount(
        _ count: Int,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        switch language {
        case .english:
            return "\(count) items"
        case .korean:
            return "\(count)개 항목"
        case .japanese:
            return "\(count)件"
        }
    }

    static func upToDate(
        version: String,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let template = text(.upToDate, appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return String(format: template, version)
    }

    static func unsupportedVersion(
        version: String,
        requirement: String,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let template = text(.unsupportedVersion, appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return String(format: template, version, requirement)
    }

    static func newerThanVersion(
        _ version: String,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let template = text(.newerThanVersion, appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return String(format: template, version)
    }

    static func availableUpdateMessage(
        version: String,
        key: PreferencesTextKey,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let template = text(key, appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return String(format: template, version)
    }
}

extension PreferencesL10n {
    enum ResolvedLanguage {
        case english
        case korean
        case japanese
    }

    private static func resolvedLanguage(
        appLanguage: SpillAppLanguage,
        preferredLanguages: [String]
    ) -> ResolvedLanguage {
        if let languageCode = appLanguage.languageCode,
           let language = matching(languageCode)
        {
            return language
        }

        for languageID in preferredLanguages {
            if let language = matching(languageID) {
                return language
            }
        }
        return .english
    }

    private static func matching(_ languageID: String) -> ResolvedLanguage? {
        let normalized = languageID.lowercased()
        if normalized.hasPrefix("ko") { return .korean }
        if normalized.hasPrefix("ja") { return .japanese }
        if normalized.hasPrefix("en") { return .english }
        return nil
    }
}
