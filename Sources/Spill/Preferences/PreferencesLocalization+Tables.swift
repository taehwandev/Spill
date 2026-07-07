import Foundation

extension PreferencesL10n {
    static let table: [ResolvedLanguage: [PreferencesTextKey: String]] = [
        .english: preferencesEnglishText,
        .korean: preferencesKoreanText,
        .japanese: preferencesJapaneseText
    ]

    private static func mergeTextParts(_ parts: [PreferencesTextKey: String]...) -> [PreferencesTextKey: String] {
        parts.reduce(into: [:]) { merged, part in
            merged.merge(part) { _, new in new }
        }
    }
}

extension PreferencesL10n {
    static let preferencesEnglishText: [PreferencesTextKey: String] = mergeTextParts(
        preferencesEnglishTextPart1,
        preferencesEnglishTextPart2
    )
}

extension PreferencesL10n {
    static let preferencesKoreanText: [PreferencesTextKey: String] = mergeTextParts(
        preferencesKoreanTextPart1,
        preferencesKoreanTextPart2
    )
}

extension PreferencesL10n {
    static let preferencesJapaneseText: [PreferencesTextKey: String] = mergeTextParts(
        preferencesJapaneseTextPart1,
        preferencesJapaneseTextPart2
    )
}
