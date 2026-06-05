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

private final class SparkleVersionComparator: NSObject, SUVersionComparison {
    func compareVersion(_ versionA: String, toVersion versionB: String) -> ComparisonResult {
        let localVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let localShort = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

        var normalizedA = versionA
        var normalizedB = versionB

        // If Sparkle passes the build version placeholder (e.g. "1"), substitute with the actual short version
        if versionA == localVersion {
            normalizedA = localShort
        }
        if versionB == localVersion {
            normalizedB = localShort
        }

        let a = DottedVersion(normalizedA) ?? .zero
        let b = DottedVersion(normalizedB) ?? .zero

        if a < b {
            return .orderedAscending
        } else if a > b {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
}
