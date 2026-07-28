import Foundation

enum TokenMeteringSetupL10n {
    enum Key: String {
        case aiToolVisibilityNoInstalledTools
        case historyImportNoInstalledTools
        case setupDashboardTitle
        case setupInstall
        case setupInstalling
        case setupReinstall
        case setupStatusFailed
        case setupStatusInstalled
        case setupStatusInstalling
        case setupStatusNotInstalled
        case setupStatusSucceeded
    }

    private static let tableName = "TokenMetering"
    private static let keyPrefix = "token_metering"
    private static let cachedResourceBundle = SpillResourceBundle.resourceBundle()
    private static let cachedLocalizedBundles: [TokenMeteringLanguage: Bundle] = {
        guard let resourceBundle = cachedResourceBundle else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: TokenMeteringLanguage.allCases.compactMap { language in
            guard let path = resourceBundle.path(forResource: language.rawValue, ofType: "lproj"),
                  let bundle = Bundle(path: path)
            else {
                return nil
            }
            return (language, bundle)
        })
    }()

    static func text(_ key: Key, language: TokenMeteringLanguage) -> String {
        let localizationKey = "\(keyPrefix).\(key.rawValue)"
        if let bundle = localizedBundle(for: language) {
            let value = bundle.localizedString(forKey: localizationKey, value: nil, table: tableName)
            if value != localizationKey {
                return value
            }
        }
        return stringCatalogValue(for: localizationKey, language: language) ?? localizationKey
    }

    private static func localizedBundle(for language: TokenMeteringLanguage) -> Bundle? {
        cachedLocalizedBundles[language] ?? cachedResourceBundle
    }

    private static func stringCatalogValue(for key: String, language: TokenMeteringLanguage) -> String? {
        guard let entry = stringCatalog?.strings[key] else {
            return nil
        }
        return entry.localizations[language.rawValue]?.stringUnit?.value
            ?? entry.localizations[TokenMeteringLanguage.english.rawValue]?.stringUnit?.value
    }

    private static let stringCatalog: StringCatalog? = {
        guard let bundle = cachedResourceBundle else {
            return nil
        }
        let candidateURLs = [
            bundle.url(forResource: tableName, withExtension: "xcstrings"),
            bundle.url(forResource: tableName, withExtension: "xcstrings", subdirectory: "Localization")
        ].compactMap(\.self)

        for url in candidateURLs {
            guard let data = try? Data(contentsOf: url),
                  let catalog = try? JSONDecoder().decode(StringCatalog.self, from: data)
            else {
                continue
            }
            return catalog
        }
        return nil
    }()

    private struct StringCatalog: Decodable, Sendable {
        let strings: [String: Entry]
    }

    private struct Entry: Decodable, Sendable {
        let localizations: [String: Localization]
    }

    private struct Localization: Decodable, Sendable {
        let stringUnit: StringUnit?
    }

    private struct StringUnit: Decodable, Sendable {
        let value: String
    }
}
