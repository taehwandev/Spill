import Foundation
import Sparkle

@MainActor
final class SparkleUpdateController {
    private let updaterController: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        guard Self.hasSparkleConfiguration(in: bundle) else {
            updaterController = nil
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
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
}
