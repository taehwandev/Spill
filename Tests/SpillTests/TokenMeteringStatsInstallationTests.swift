import Foundation
import XCTest
@testable import Spill

final class TokenMeteringStatsInstallationTests: XCTestCase {
    private let helperName = "spill-token-metering-stats.mjs"
    private let moduleNames = [
        "spill-token-metering-stats-accounting.mjs",
        "spill-token-metering-stats-presentation.mjs",
    ]

    func testFreshInstallationIncludesRunnableStatsModules() throws {
        let fixture = try makeFixture()
        try TokenMeteringSetupInstaller.installStatsHelper(from: fixture.source, to: fixture.destination)
        try assertInstalledResources(source: fixture.source, destination: fixture.destination)
        try assertAntigravityReport(helper: fixture.destination)
    }

    func testRefreshRepairsMissingModuleAndReplacesStaleResources() throws {
        let fixture = try makeFixture()
        try FileManager.default.createDirectory(
            at: fixture.destination.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try "stale helper".write(to: fixture.destination, atomically: true, encoding: .utf8)
        try "stale module".write(
            to: fixture.destination.deletingLastPathComponent().appendingPathComponent(moduleNames[0]),
            atomically: true, encoding: .utf8
        )
        XCTAssertTrue(try TokenMeteringSetupInstaller.refreshInstalledStatsHelperIfPresent(
            sourceURL: fixture.source, destination: fixture.destination
        ))
        try assertInstalledResources(source: fixture.source, destination: fixture.destination)
        try assertAntigravityReport(helper: fixture.destination)
    }

    func testRefreshLeavesUninstalledStatsHelperAndModulesAbsent() throws {
        let fixture = try makeFixture()
        XCTAssertFalse(try TokenMeteringSetupInstaller.refreshInstalledStatsHelperIfPresent(
            sourceURL: fixture.source, destination: fixture.destination
        ))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.deletingLastPathComponent().path))
    }

    func testMissingBundledModuleDoesNotReplaceExistingInstallation() throws {
        let fixture = try makeFixture()
        try TokenMeteringSetupInstaller.installStatsHelper(from: fixture.source, to: fixture.destination)
        try "old helper".write(to: fixture.destination, atomically: true, encoding: .utf8)
        let installedModule = fixture.destination.deletingLastPathComponent().appendingPathComponent(moduleNames[0])
        try "old module".write(to: installedModule, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(
            at: fixture.source.deletingLastPathComponent().appendingPathComponent(moduleNames[1])
        )
        XCTAssertThrowsError(try TokenMeteringSetupInstaller.refreshInstalledStatsHelperIfPresent(
            sourceURL: fixture.source, destination: fixture.destination
        ))
        XCTAssertEqual(try String(contentsOf: fixture.destination, encoding: .utf8), "old helper")
        XCTAssertEqual(try String(contentsOf: installedModule, encoding: .utf8), "old module")
    }

    private func makeFixture() throws -> (source: URL, destination: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let resources = repo.appendingPathComponent("Sources/Spill/Resources/adapters/setup")
        let sourceDirectory = root.appendingPathComponent("bundled")
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        for name in [helperName] + moduleNames {
            try FileManager.default.copyItem(
                at: resources.appendingPathComponent(name), to: sourceDirectory.appendingPathComponent(name)
            )
        }
        return (
            sourceDirectory.appendingPathComponent(helperName),
            root.appendingPathComponent("installed/setup").appendingPathComponent(helperName)
        )
    }

    private func assertInstalledResources(source: URL, destination: URL) throws {
        for name in [helperName] + moduleNames {
            let installed = destination.deletingLastPathComponent().appendingPathComponent(name)
            XCTAssertEqual(
                try Data(contentsOf: installed),
                try Data(contentsOf: source.deletingLastPathComponent().appendingPathComponent(name))
            )
            let attrs = try FileManager.default.attributesOfItem(atPath: installed.path)
            let permissions = try XCTUnwrap(attrs[.posixPermissions] as? Int)
            XCTAssertEqual(permissions & 0o777, name == helperName ? 0o700 : 0o600)
        }
    }

    private func assertAntigravityReport(helper: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "node", helper.path, "--tool", "agy", "--json", "--database",
            helper.deletingLastPathComponent().appendingPathComponent("missing.sqlite3").path,
        ]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, String(decoding: data, as: UTF8.self))
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let scope = try XCTUnwrap(report["scope"] as? [String: Any])
        XCTAssertEqual(scope["tool"] as? String, "antigravity")
        XCTAssertEqual(report["reason"] as? String, "store_not_found")
    }
}
