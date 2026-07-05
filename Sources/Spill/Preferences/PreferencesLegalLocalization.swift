import Foundation

enum PreferencesLegalL10n {
    enum TextKey: String {
        case legalAndPrivacy
        case legalAndPrivacyDetail
        case privacyPolicy
        case termsOfService
        case syncDataHandling
        case syncDataLegalDetail
    }

    static func text(
        _ key: TextKey,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return table[language]?[key] ?? table[.english]?[key] ?? key.rawValue
    }

    private enum ResolvedLanguage {
        case english
        case korean
        case japanese
    }

    private static func resolvedLanguage(
        appLanguage: SpillAppLanguage,
        preferredLanguages: [String]
    ) -> ResolvedLanguage {
        switch appLanguage {
        case .english:
            return .english
        case .korean:
            return .korean
        case .japanese:
            return .japanese
        case .automatic:
            for languageID in preferredLanguages {
                if let language = matching(languageID) {
                    return language
                }
            }
            return .english
        }
    }

    private static func matching(_ languageID: String) -> ResolvedLanguage? {
        let normalized = languageID.lowercased()
        if normalized.hasPrefix("ko") { return .korean }
        if normalized.hasPrefix("ja") { return .japanese }
        if normalized.hasPrefix("en") { return .english }
        return nil
    }

    private static let table: [ResolvedLanguage: [TextKey: String]] = [
        .english: [
            .legalAndPrivacy: "Legal & Privacy",
            .legalAndPrivacyDetail: "Review how Spill handles app data, optional encrypted sync, and service terms.",
            .privacyPolicy: "Privacy Policy",
            .termsOfService: "Terms of Service",
            .syncDataHandling: "Sync Data Handling",
            .syncDataLegalDetail: "Optional sync uploads encrypted daily usage totals and device metadata only after this Mac is connected. Review the policy and terms before enabling it."
        ],
        .korean: [
            .legalAndPrivacy: "개인정보 및 약관",
            .legalAndPrivacyDetail: "Spill의 앱 데이터, 선택적 암호화 동기화, 서비스 약관 처리 방식을 확인하세요.",
            .privacyPolicy: "개인정보 처리방침",
            .termsOfService: "서비스 이용약관",
            .syncDataHandling: "동기화 데이터 처리 안내",
            .syncDataLegalDetail: "동기화는 이 Mac을 연결한 뒤 암호화된 일별 사용량 합계와 기기 메타데이터만 업로드합니다. 켜기 전에 처리방침과 약관을 확인하세요."
        ],
        .japanese: [
            .legalAndPrivacy: "法務とプライバシー",
            .legalAndPrivacyDetail: "Spill のアプリデータ、任意の暗号化同期、サービス規約の扱いを確認できます。",
            .privacyPolicy: "プライバシーポリシー",
            .termsOfService: "利用規約",
            .syncDataHandling: "同期データの取り扱い",
            .syncDataLegalDetail: "任意の同期は、この Mac を接続した後に暗号化された日別使用量合計とデバイスメタデータのみをアップロードします。有効にする前にポリシーと規約を確認してください。"
        ]
    ]
}
