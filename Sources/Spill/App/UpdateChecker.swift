import Foundation

struct UpdateManifest: Codable, Equatable, Sendable {
    let latestVersion: String
    let build: String?
    let minimumMacOS: String?
    let downloadURL: URL
    let packageURL: URL?
    let releaseNotesURL: URL?
    let publishedAt: String?
}

struct AvailableUpdate: Equatable, Sendable {
    let currentVersion: String
    let latestVersion: String
    let build: String?
    let minimumMacOS: String?
    let downloadURL: URL
    let packageURL: URL?
    let releaseNotesURL: URL?
    let publishedAt: String?

    var preferredDownloadURL: URL {
        packageURL ?? downloadURL
    }

    var usesInstallerPackage: Bool {
        packageURL != nil
    }
}

enum UpdateCheckOutcome: Equatable, Sendable {
    case upToDate(currentVersion: String, manifest: UpdateManifest)
    case available(AvailableUpdate)
    case unsupported(AvailableUpdate, currentMacOS: String)
}

enum UpdateCheckError: LocalizedError, Equatable, Sendable {
    case invalidHTTPStatus(Int)
    case invalidLatestVersion(String)
    case invalidMinimumMacOS(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidHTTPStatus(let statusCode):
            return AppL10n.updateHTTPFailed(statusCode: statusCode)
        case .invalidLatestVersion(let version):
            return AppL10n.invalidLatestVersion(version)
        case .invalidMinimumMacOS(let version):
            return AppL10n.invalidMacOSVersion(version)
        case .decodingFailed(let message):
            return AppL10n.updateDecodingFailed(message)
        }
    }
}

struct UpdateChecker: Sendable {
    static let defaultManifestURL = URL(
        string: "https://github.com/taehwandev/Spill/releases/latest/download/update.json"
    )!
    static let defaultLatestReleaseURL = URL(
        string: "https://api.github.com/repos/taehwandev/Spill/releases/latest"
    )!

    let manifestURL: URL
    let latestReleaseURL: URL
    let currentVersion: String
    let currentMacOS: DottedVersion
    let dataLoader: @Sendable (URL) async throws -> Data

    init(
        manifestURL: URL = Self.defaultManifestURL,
        latestReleaseURL: URL = Self.defaultLatestReleaseURL,
        currentVersion: String = Bundle.main.spillShortVersion,
        currentMacOS: DottedVersion = DottedVersion(ProcessInfo.processInfo.operatingSystemVersion),
        dataLoader: @escaping @Sendable (URL) async throws -> Data = Self.liveData(from:)
    ) {
        self.manifestURL = manifestURL
        self.latestReleaseURL = latestReleaseURL
        self.currentVersion = currentVersion
        self.currentMacOS = currentMacOS
        self.dataLoader = dataLoader
    }

    func check() async throws -> UpdateCheckOutcome {
        let manifest: UpdateManifest
        do {
            let data = try await dataLoader(manifestURL)
            manifest = try decodeManifest(from: data)
        } catch UpdateCheckError.invalidHTTPStatus(404) {
            let data = try await dataLoader(latestReleaseURL)
            manifest = try decodeLatestRelease(from: data)
        }

        return try outcome(for: manifest)
    }

    func outcome(for manifest: UpdateManifest) throws -> UpdateCheckOutcome {
        guard let latestVersion = DottedVersion(manifest.latestVersion) else {
            throw UpdateCheckError.invalidLatestVersion(manifest.latestVersion)
        }

        let current = DottedVersion(currentVersion) ?? .zero
        let update = AvailableUpdate(
            currentVersion: currentVersion,
            latestVersion: manifest.latestVersion,
            build: manifest.build,
            minimumMacOS: manifest.minimumMacOS,
            downloadURL: manifest.downloadURL,
            packageURL: manifest.packageURL,
            releaseNotesURL: manifest.releaseNotesURL,
            publishedAt: manifest.publishedAt
        )

        if latestVersion > current {
            if let minimumMacOS = manifest.minimumMacOS {
                guard let minimum = DottedVersion(minimumMacOS) else {
                    throw UpdateCheckError.invalidMinimumMacOS(minimumMacOS)
                }

                if currentMacOS < minimum {
                    return .unsupported(update, currentMacOS: currentMacOS.description)
                }
            }

            return .available(update)
        }

        return .upToDate(currentVersion: currentVersion, manifest: manifest)
    }

    private func decodeManifest(from data: Data) throws -> UpdateManifest {
        do {
            return try JSONDecoder().decode(UpdateManifest.self, from: data)
        } catch {
            throw UpdateCheckError.decodingFailed(error.localizedDescription)
        }
    }

    private func decodeLatestRelease(from data: Data) throws -> UpdateManifest {
        do {
            let release = try JSONDecoder().decode(GitHubLatestRelease.self, from: data)
            let latestVersion = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName
            let preferredPackageAssetNames = [
                "Spill-macos.pkg",
                "Spill-\(latestVersion)-macos.pkg"
            ]
            let preferredDownloadAssetNames = [
                "Spill-macos.dmg",
                "Spill-\(latestVersion)-macos.dmg",
                "Spill-macos.zip",
                "Spill-\(latestVersion)-macos.zip",
                "Spill-macos.pkg",
                "Spill-\(latestVersion)-macos.pkg"
            ]
            let packageAsset = preferredPackageAssetNames.compactMap { name in
                release.assets.first { $0.name == name }
            }.first

            guard let asset = preferredDownloadAssetNames.compactMap({ name in
                release.assets.first { $0.name == name }
            }).first else {
                throw UpdateCheckError.decodingFailed(AppL10n.text(.missingMacOSDownloadAsset))
            }

            return UpdateManifest(
                latestVersion: latestVersion,
                build: nil,
                minimumMacOS: "14.0",
                downloadURL: asset.browserDownloadURL,
                packageURL: packageAsset?.browserDownloadURL,
                releaseNotesURL: release.htmlURL,
                publishedAt: release.publishedAt
            )
        } catch let error as UpdateCheckError {
            throw error
        } catch {
            throw UpdateCheckError.decodingFailed(error.localizedDescription)
        }
    }

    private static func liveData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw UpdateCheckError.invalidHTTPStatus(httpResponse.statusCode)
        }

        return data
    }
}

private struct GitHubLatestRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let publishedAt: String?
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

struct DottedVersion: Comparable, CustomStringConvertible, Equatable, Sendable {
    static let zero = DottedVersion(components: [0, 0, 0])

    let components: [Int]

    init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else {
            return nil
        }

        var parsed: [Int] = []
        parsed.reserveCapacity(parts.count)

        for part in parts {
            guard let value = Int(part), value >= 0 else {
                return nil
            }
            parsed.append(value)
        }

        components = parsed
    }

    init(_ version: OperatingSystemVersion) {
        components = [version.majorVersion, version.minorVersion, version.patchVersion]
    }

    // Normalizes a Sparkle version string: if it matches the installed bundle version (e.g. a legacy "1"
    // build number placeholder), substitutes the short version string so cross-week comparisons work.
    init?(normalizing version: String, bundleVersion: String, shortVersion: String) {
        let resolved = version == bundleVersion && !shortVersion.isEmpty ? shortVersion : version
        guard let parsed = DottedVersion(resolved) else {
            return nil
        }
        self = parsed
    }

    private init(components: [Int]) {
        self.components = components
    }

    var description: String {
        components.map(String.init).joined(separator: ".")
    }

    static func == (lhs: DottedVersion, rhs: DottedVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    static func < (lhs: DottedVersion, rhs: DottedVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)

        for index in 0..<maxCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0

            if left != right {
                return left < right
            }
        }

        return false
    }
}

private extension Bundle {
    var spillShortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}
