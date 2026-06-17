import Foundation
import Sparkle

@MainActor
final class SparkleUpdateController: NSObject, SPUUpdaterDelegate {
    private var updaterController: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        super.init()

        guard Self.hasSparkleConfiguration(in: bundle) else {
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    var isAvailable: Bool {
        updaterController != nil
    }

    func checkForUpdates() -> Bool {
        guard let updaterController else {
            return false
        }

        updaterController.checkForUpdates(nil)
        return true
    }

    private static func hasSparkleConfiguration(in bundle: Bundle) -> Bool {
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String

        return feedURL?.isEmpty == false && publicKey?.isEmpty == false
    }

    // MARK: - SPUUpdaterDelegate

    func versionComparator(for updater: SPUUpdater) -> SUVersionComparison? {
        SparkleVersionComparator()
    }
}

final class SparkleVersionComparator: NSObject, SUVersionComparison {
    let localBundleVersion: String
    let localShortVersion: String

    init(bundle: Bundle = .main) {
        self.localBundleVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        self.localShortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    func compareVersion(_ versionA: String, toVersion versionB: String) -> ComparisonResult {
        let a = DottedVersion(normalizing: versionA, bundleVersion: localBundleVersion, shortVersion: localShortVersion) ?? .zero
        let b = DottedVersion(versionB) ?? .zero

        if a < b {
            return .orderedAscending
        } else if a > b {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
}
