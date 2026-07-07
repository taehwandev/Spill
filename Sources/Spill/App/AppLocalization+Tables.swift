import Foundation

extension AppL10n {
    static let table: [ResolvedLanguage: [AppTextKey: String]] = [
        .english: appEnglishText,
        .korean: appKoreanText,
        .japanese: appJapaneseText
    ]

    private static func mergeTextParts(_ parts: [AppTextKey: String]...) -> [AppTextKey: String] {
        parts.reduce(into: [:]) { merged, part in
            merged.merge(part) { _, new in new }
        }
    }
}

extension AppL10n {
    static let appEnglishText: [AppTextKey: String] = mergeTextParts(
        appEnglishTextPart1,
        appEnglishTextPart2,
        appEnglishTextPart3,
        appEnglishTextPart4,
        appEnglishTextPart5
    )
}

extension AppL10n {
    static let appKoreanText: [AppTextKey: String] = mergeTextParts(
        appKoreanTextPart1,
        appKoreanTextPart2,
        appKoreanTextPart3,
        appKoreanTextPart4,
        appKoreanTextPart5
    )
}

extension AppL10n {
    static let appJapaneseText: [AppTextKey: String] = mergeTextParts(
        appJapaneseTextPart1,
        appJapaneseTextPart2,
        appJapaneseTextPart3,
        appJapaneseTextPart4,
        appJapaneseTextPart5
    )
}
