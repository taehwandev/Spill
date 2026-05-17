import XCTest
@testable import Spill

final class UpdateCheckerTests: XCTestCase {
    func testDottedVersionComparisonPadsMissingComponents() {
        XCTAssertTrue(DottedVersion("2026.20.2")! > DottedVersion("2026.20.1")!)
        XCTAssertTrue(DottedVersion("2026.20.10")! > DottedVersion("2026.20.2")!)
        XCTAssertEqual(DottedVersion("2026.20")!, DottedVersion("2026.20.0")!)
        XCTAssertNil(DottedVersion("2026.beta.1"))
    }

    func testOutcomeReturnsAvailableWhenManifestVersionIsNewer() throws {
        let manifest = makeManifest(latestVersion: "2026.20.2")
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in Data() }
        )

        let outcome = try checker.outcome(for: manifest)

        XCTAssertEqual(
            outcome,
            .available(
                AvailableUpdate(
                    currentVersion: "2026.20.1",
                    latestVersion: "2026.20.2",
                    build: "42",
                    minimumMacOS: "14.0",
                    downloadURL: manifest.downloadURL,
                    releaseNotesURL: manifest.releaseNotesURL,
                    publishedAt: manifest.publishedAt
                )
            )
        )
    }

    func testOutcomeReturnsUpToDateWhenManifestVersionMatches() throws {
        let manifest = makeManifest(latestVersion: "2026.20.2")
        let checker = UpdateChecker(
            currentVersion: "2026.20.2",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in Data() }
        )

        let outcome = try checker.outcome(for: manifest)

        XCTAssertEqual(outcome, .upToDate(currentVersion: "2026.20.2", manifest: manifest))
    }

    func testOutcomeIgnoresMinimumMacOSWhenNoNewerVersionExists() throws {
        let manifest = makeManifest(latestVersion: "2026.20.2", minimumMacOS: "15.0")
        let checker = UpdateChecker(
            currentVersion: "2026.20.2",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in Data() }
        )

        let outcome = try checker.outcome(for: manifest)

        XCTAssertEqual(outcome, .upToDate(currentVersion: "2026.20.2", manifest: manifest))
    }

    func testOutcomeReturnsUnsupportedWhenMacOSIsTooOld() throws {
        let manifest = makeManifest(latestVersion: "2026.20.2", minimumMacOS: "15.0")
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in Data() }
        )

        let outcome = try checker.outcome(for: manifest)

        XCTAssertEqual(
            outcome,
            .unsupported(
                AvailableUpdate(
                    currentVersion: "2026.20.1",
                    latestVersion: "2026.20.2",
                    build: "42",
                    minimumMacOS: "15.0",
                    downloadURL: manifest.downloadURL,
                    releaseNotesURL: manifest.releaseNotesURL,
                    publishedAt: manifest.publishedAt
                ),
                currentMacOS: "14.5.0"
            )
        )
    }

    func testCheckLoadsAndDecodesManifest() async throws {
        let data = """
        {
          "latestVersion": "2026.20.2",
          "build": "42",
          "minimumMacOS": "14.0",
          "downloadURL": "https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.dmg",
          "releaseNotesURL": "https://github.com/taehwandev/Spill/releases/latest",
          "publishedAt": "2026-05-17T00:00:00Z"
        }
        """.data(using: .utf8)!
        let checker = UpdateChecker(
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { _ in data }
        )

        let outcome = try await checker.check()

        guard case .available(let update) = outcome else {
            XCTFail("Expected available update.")
            return
        }

        XCTAssertEqual(update.latestVersion, "2026.20.2")
        XCTAssertEqual(update.build, "42")
    }

    func testCheckFallsBackToLatestGitHubReleaseWhenManifestIsMissing() async throws {
        let manifestURL = URL(string: "https://example.com/update.json")!
        let latestReleaseURL = URL(string: "https://example.com/releases/latest")!
        let releaseData = """
        {
          "tag_name": "v2026.20.2",
          "html_url": "https://github.com/taehwandev/Spill/releases/tag/v2026.20.2",
          "published_at": "2026-05-17T00:00:00Z",
          "assets": [
            {
              "name": "Spill-macos.dmg",
              "browser_download_url": "https://github.com/taehwandev/Spill/releases/download/v2026.20.2/Spill-macos.dmg"
            }
          ]
        }
        """.data(using: .utf8)!
        let checker = UpdateChecker(
            manifestURL: manifestURL,
            latestReleaseURL: latestReleaseURL,
            currentVersion: "2026.20.1",
            currentMacOS: DottedVersion("14.5.0")!,
            dataLoader: { url in
                if url == manifestURL {
                    throw UpdateCheckError.invalidHTTPStatus(404)
                }

                guard url == latestReleaseURL else {
                    return Data()
                }

                return releaseData
            }
        )

        let outcome = try await checker.check()

        guard case .available(let update) = outcome else {
            XCTFail("Expected available update.")
            return
        }

        XCTAssertEqual(update.latestVersion, "2026.20.2")
        XCTAssertNil(update.build)
        XCTAssertEqual(update.minimumMacOS, "14.0")
        XCTAssertEqual(update.downloadURL.absoluteString, "https://github.com/taehwandev/Spill/releases/download/v2026.20.2/Spill-macos.dmg")
        XCTAssertEqual(update.releaseNotesURL?.absoluteString, "https://github.com/taehwandev/Spill/releases/tag/v2026.20.2")
    }

    func testDefaultUpdateURLsPointAtPublicSpillRepo() {
        XCTAssertEqual(
            UpdateChecker.defaultManifestURL.absoluteString,
            "https://github.com/taehwandev/Spill/releases/latest/download/update.json"
        )
        XCTAssertEqual(
            UpdateChecker.defaultLatestReleaseURL.absoluteString,
            "https://api.github.com/repos/taehwandev/Spill/releases/latest"
        )
    }

    private func makeManifest(
        latestVersion: String,
        minimumMacOS: String = "14.0"
    ) -> UpdateManifest {
        UpdateManifest(
            latestVersion: latestVersion,
            build: "42",
            minimumMacOS: minimumMacOS,
            downloadURL: URL(string: "https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.dmg")!,
            releaseNotesURL: URL(string: "https://github.com/taehwandev/Spill/releases/latest")!,
            publishedAt: "2026-05-17T00:00:00Z"
        )
    }
}
