import Foundation
import XCTest
@testable import Spill

final class TokenUsageStoreSchemaTests: XCTestCase {
    func testSameStorePreparesSchemaAfterDatabaseFileIsRecreated() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenUsageStoreSchemaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = TokenUsageStore(fileURL: directoryURL.appendingPathComponent("events.json"))
        _ = try store.appendEvent(Self.event(spanID: "span_schema_01"))
        XCTAssertEqual(store.loadEvents().map(\.spanID), ["span_schema_01"])

        try removeSQLiteFiles(at: store.eventsDatabaseURL)

        _ = try store.appendEvent(Self.event(spanID: "span_schema_02"))

        XCTAssertEqual(store.loadEvents().map(\.spanID), ["span_schema_02"])
    }

    private func removeSQLiteFiles(at databaseURL: URL) throws {
        let sidecarURLs = [
            databaseURL,
            URL(fileURLWithPath: "\(databaseURL.path)-wal"),
            URL(fileURLWithPath: "\(databaseURL.path)-shm")
        ]

        for url in sidecarURLs where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static func event(spanID: String) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_schema",
            projectID: "project_schema",
            artifactID: "artifact_schema",
            runID: "run_schema",
            spanID: spanID,
            aiTool: .codex,
            taskType: "testing",
            stage: "verify",
            model: "test-model",
            inputTokens: 7,
            outputTokens: 3,
            totalTokens: 10,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0,
                user: 0,
                history: 0,
                repoContext: 0,
                toolOutput: 0,
                generatedOutput: 0,
                unknown: 10
            ),
            latencyMS: 0,
            createdAt: "2026-06-07T04:00:00.000Z"
        )
    }
}
