import AppKit
import Foundation

enum SpillResourceBundle {
    private static let bundleName = "Spill_Spill.bundle"

    static func image(named name: String) -> NSImage? {
        resourceBundle()?.image(forResource: name)
    }

    static func resourceBundle(
        mainBundleURL: URL = Bundle.main.bundleURL,
        mainResourceURL: URL? = Bundle.main.resourceURL,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> Bundle? {
        if let packagedBundle = packagedResourceBundle(
            mainBundleURL: mainBundleURL,
            mainResourceURL: mainResourceURL,
            fileExists: fileExists
        ) {
            return packagedBundle
        }

        #if DEBUG
        return .module
        #else
        return nil
        #endif
    }

    static func packagedResourceBundle(
        mainBundleURL: URL = Bundle.main.bundleURL,
        mainResourceURL: URL? = Bundle.main.resourceURL,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> Bundle? {
        for candidateURL in packagedResourceBundleCandidateURLs(
            mainBundleURL: mainBundleURL,
            mainResourceURL: mainResourceURL
        ) where fileExists(candidateURL.path) {
            if let bundle = Bundle(url: candidateURL) {
                return bundle
            }
        }
        return nil
    }

    static func packagedResourceBundleCandidateURLs(
        mainBundleURL: URL,
        mainResourceURL: URL?
    ) -> [URL] {
        [
            mainResourceURL?.appendingPathComponent(bundleName, isDirectory: true),
            mainBundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent(bundleName, isDirectory: true),
            mainBundleURL.appendingPathComponent(bundleName, isDirectory: true)
        ].compactMap(\.self)
    }
}
