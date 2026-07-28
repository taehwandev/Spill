import XCTest
@testable import Spill

final class TokenMeteringSetupLocalizationTests: XCTestCase {
    func testSetupLocalizationCachesResourceAndLocalizedBundles() throws {
        let source = try Self.source(named: "TokenMeteringSetupLocalization.swift")

        XCTAssertTrue(source.contains("private static let cachedResourceBundle"))
        XCTAssertTrue(source.contains("private static let cachedLocalizedBundles"))
        XCTAssertEqual(
            source.components(separatedBy: "SpillResourceBundle.resourceBundle()").count - 1,
            1
        )
    }

    private static func source(named fileName: String) throws -> String {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourcesURL = root.appendingPathComponent("Sources/Spill", isDirectory: true)
        let urls = FileManager.default.enumerator(
            at: sourcesURL,
            includingPropertiesForKeys: nil
        )?
            .compactMap { $0 as? URL }
            .filter { $0.lastPathComponent == fileName }
            .sorted { $0.path < $1.path } ?? []
        let sourceURL = try XCTUnwrap(urls.first, "Missing source file named \(fileName)")
        return try String(contentsOf: sourceURL)
    }
}
