import Foundation
import XCTest
@testable import Spill

final class TokenUsageToolActivityPolicyTests: XCTestCase {
    func testSmokeStartupLeavesExistingAdapterPolicyUnchanged() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillToolActivity-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("enabled-tools.json")
        try TokenUsageToolActivityPolicy.write(enabledTools: [.codex], to: url)
        let before = try Data(contentsOf: url)

        try TokenUsageToolActivityPolicy.write(enabledTools: [.claude], to: url, isSmokeTest: true)

        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testSmokeStartupDoesNotCreateAdapterPolicy() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillToolActivity-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("enabled-tools.json")
        try TokenUsageToolActivityPolicy.write(enabledTools: [.claude], to: url, isSmokeTest: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testSnapshotUsesAdapterContractAndOwnerOnlyPermissions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillToolActivity-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("enabled-tools.json")

        try TokenUsageToolActivityPolicy.write(enabledTools: [.claude, .antigravity], to: url)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(object["schema_version"] as? Int, 1)
        XCTAssertEqual(object["enabled_tools"] as? [String], ["antigravity", "claude"])
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o600)
    }
}
