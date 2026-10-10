import Darwin
import Foundation
import XCTest
@testable import Spill

final class TokenUsageAntigravityQuotaTests: XCTestCase {
    private let capturedAt = Date(timeIntervalSince1970: 1_000_000)

    func testNativeFourBucketsKeepPoolIdentityAndExactFractions() throws {
        let groups = TokenUsageAntigravityQuotaParser.parse(try Self.report(), capturedAt: capturedAt)
        let snapshots = groups.flatMap(\.snapshots)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(snapshots.count, 4)
        XCTAssertEqual(snapshots.map(\.limitKey), [
            "agy_quota:gemini:5h", "agy_quota:gemini:weekly",
            "agy_quota:claude_gpt:5h", "agy_quota:claude_gpt:weekly",
        ])
        XCTAssertEqual(snapshots[0].remainingPercent!, 85.29884219169617, accuracy: 0.000001)
        XCTAssertEqual(snapshots[1].remainingPercent!, 67.02931523323059, accuracy: 0.000001)
        XCTAssertEqual(snapshots[2].remainingPercent, 100)
        XCTAssertTrue(snapshots.allSatisfy { $0.source == .clientCache && $0.capturedAt == capturedAt })
        XCTAssertTrue(snapshots.allSatisfy { $0.isScopedVariant && $0.resetsAt != nil })
    }

    func testRejectsErrorAgentTurnsWrongCommandAndMalformedJSON() throws {
        for data in [
            try Self.report(status: "ERROR"), try Self.report(command: "other"),
            try Self.report(turns: 1), Data("not JSON".utf8),
        ] {
            XCTAssertTrue(TokenUsageAntigravityQuotaParser.parse(data, capturedAt: capturedAt).isEmpty)
        }
    }

    func testInvalidPoolPreservesItWhileAnotherPoolRefreshes() throws {
        let original = try Self.report()
        let context = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }
        var current = capturedAt
        var output: Data? = original
        let capture = TokenUsageAntigravityLimitCapture(
            runner: { _ in output }, now: { current },
            lockURL: context.directory.appendingPathComponent("capture.lock"), reuseInterval: 0
        )
        capture.captureLatestSnapshots(into: context.store)
        let first = context.store.storedSnapshots()
        XCTAssertEqual(first.count, 4)
        current = capturedAt.addingTimeInterval(60)
        output = try Self.report(geminiFraction: 1.2)
        capture.captureLatestSnapshots(into: context.store)
        let second = context.store.storedSnapshots()
        XCTAssertEqual(second.filter { $0.limitKey.hasPrefix("agy_quota:gemini:") },
                       first.filter { $0.limitKey.hasPrefix("agy_quota:gemini:") })
        XCTAssertTrue(second.filter { $0.limitKey.hasPrefix("agy_quota:claude_gpt:") }
            .allSatisfy { $0.capturedAt == current })
        output = nil
        current = current.addingTimeInterval(60)
        capture.captureLatestSnapshots(into: context.store)
        XCTAssertEqual(context.store.storedSnapshots(), second)
    }

    func testCompletePoolRetiresSiblingAndLeavesOtherToolUntouched() throws {
        let context = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }
        let existing = TokenUsageLimitSnapshot(aiTool: .codex, limitKey: "codex:weekly",
            label: "Weekly", usedPercent: 10, remainingCredits: nil, windowMinutes: 10_080,
            resetsAt: nil, capturedAt: capturedAt, source: .serverExact)
        context.store.mergeSnapshots(for: .codex, with: [existing])
        context.store.replaceCompleteGroups(for: .antigravity, with:
            TokenUsageAntigravityQuotaParser.parse(try Self.report(), capturedAt: capturedAt))
        context.store.replaceCompleteGroups(for: .antigravity, with:
            TokenUsageAntigravityQuotaParser.parse(try Self.report(includeGeminiWeekly: false),
                                                  capturedAt: capturedAt.addingTimeInterval(1)))
        XCTAssertEqual(context.store.snapshots(for: .antigravity).count, 3)
        XCTAssertEqual(context.store.storedSnapshots().filter { $0.aiTool == .codex }, [existing])
    }

    func testZeroFractionIsExhaustedAndExpiredReadingBecomesUnknown() throws {
        let data = try Self.report(geminiFraction: 0)
        let snapshot = try XCTUnwrap(TokenUsageAntigravityQuotaParser.parse(data, capturedAt: capturedAt)
            .first?.snapshots.first)
        XCTAssertEqual(snapshot.remainingPercent, 0)
        let expired = snapshot.resolved(at: try XCTUnwrap(snapshot.resetsAt).addingTimeInterval(1))
        XCTAssertTrue(expired.isExpiredReading)
        XCTAssertFalse(expired.locallyReset)
        XCTAssertEqual(expired.capturedAt, capturedAt)
    }

    func testCancellationAndRecentReuseDoNotWriteOrDuplicateCommand() throws {
        let context = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }
        let data = try Self.report()
        var runs = 0
        var cancelled = false
        let capture = TokenUsageAntigravityLimitCapture(
            runner: { _ in runs += 1; cancelled = true; return data },
            now: { self.capturedAt }, lockURL: context.directory.appendingPathComponent("capture.lock")
        )
        capture.captureLatestSnapshots(into: context.store, shouldCancel: { cancelled })
        XCTAssertEqual(runs, 1)
        XCTAssertTrue(context.store.storedSnapshots().isEmpty)
        context.store.replaceCompleteGroups(for: .antigravity, with:
            TokenUsageAntigravityQuotaParser.parse(data, capturedAt: capturedAt))
        capture.captureLatestSnapshots(into: context.store)
        XCTAssertEqual(runs, 1)
    }

    func testConcurrentCaptureLockSkipsSecondRunner() throws {
        let context = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }
        let lockURL = context.directory.appendingPathComponent("capture.lock")
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o600)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        var runs = 0
        TokenUsageAntigravityLimitCapture(runner: { _ in runs += 1; return nil }, lockURL: lockURL)
            .captureLatestSnapshots(into: context.store)
        XCTAssertEqual(runs, 0)
    }

    func testUntrustedPoolsAndMissingNumbersNeverProduceMadeUpReadings() throws {
        let original = try Self.report()
        for value in ["private arbitrary pool", "Gemini Models"] {
            var report = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
            report["command"] = ["name": "usage", "data": ["groups": [[
                "name": value,
                "buckets": [["id": "gemini-5h", "window": "5h",
                              "remaining_fraction": NSNull(), "reset_time": "bad"]],
            ]]]]
            let data = try JSONSerialization.data(withJSONObject: report)
            XCTAssertTrue(TokenUsageAntigravityQuotaParser.parse(data, capturedAt: capturedAt).isEmpty)
        }
        let groups = TokenUsageAntigravityQuotaParser.parse(original, capturedAt: capturedAt)
        let encoded = try JSONEncoder().encode(groups.flatMap(\.snapshots))
        let text = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertFalse(text.contains("ignored-identity"))
        XCTAssertFalse(text.contains("ignored free-form content"))
    }

    func testVersionGateRejectsUnknownAndOldCLI() {
        for version in ["1.1.11", "1.3.3\n", "2.0.0"] {
            XCTAssertTrue(TokenUsageAntigravityQuotaCommand.supportsNativeUsage(Data(version.utf8)))
        }
        for version in ["1.1.10", "1.0.999", "0.99.99", "unknown", "1.3.3-beta"] {
            XCTAssertFalse(TokenUsageAntigravityQuotaCommand.supportsNativeUsage(Data(version.utf8)))
        }
    }

    @MainActor
    func testAGYCardShowsOnlyGeminiTwoWindowsWithoutOtherPoolExtras() throws {
        let snapshots = TokenUsageAntigravityQuotaParser.parse(try Self.report(), capturedAt: capturedAt)
            .flatMap(\.snapshots)
        let strip = TokenMeteringDashboardLimitsStrip(snapshots: snapshots, tools: [.antigravity], language: .english)
        let group = try XCTUnwrap(strip.toolGroups.first)
        XCTAssertEqual(group.tool, .antigravity)
        XCTAssertEqual(group.gauges.map(\.windowMinutes), [300, 10_080])
        XCTAssertEqual(group.snapshots.count, 2)
        XCTAssertTrue(group.snapshots.allSatisfy { $0.limitKey.hasPrefix("agy_quota:gemini:") })
        XCTAssertEqual(group.extraCount, 0)
        XCTAssertEqual(strip.slotLabel(for: group.gauges[0]), "5h")
        XCTAssertEqual(strip.slotLabel(for: group.gauges[1]), "Wk")
        let onlyOtherPool = TokenMeteringDashboardLimitsStrip(
            snapshots: snapshots.filter { $0.limitKey.hasPrefix("agy_quota:claude_gpt:") },
            tools: [.antigravity], language: .english
        )
        XCTAssertTrue(onlyOtherPool.toolGroups.isEmpty)
    }

    func testLimitsHeadingHasNoExperimentalQualifierInAnySupportedLanguage() {
        XCTAssertEqual(TokenMeteringL10n.text(.limitsTitle, language: .english), "Limits")
        XCTAssertEqual(TokenMeteringL10n.text(.limitsTitle, language: .korean), "한도")
        XCTAssertEqual(TokenMeteringL10n.text(.limitsTitle, language: .japanese), "上限")
        for language in [TokenMeteringLanguage.english, .korean, .japanese] {
            XCTAssertNotEqual(TokenMeteringL10n.text(.limitsRemaining, language: language), "limitsRemaining")
        }
    }

    private func temporaryStore() throws -> (directory: URL, store: TokenUsageLimitSnapshotStore) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("limits.json")
        return (directory, TokenUsageLimitSnapshotStore(fileURL: file, now: { self.capturedAt }))
    }

    static func report(status: String = "SUCCESS", command: String = "usage", turns: Int = 0,
                       geminiFraction: Double = 0.8529884219169617, includeGeminiWeekly: Bool = true) throws -> Data {
        func bucket(_ id: String, _ window: String, _ fraction: Double) -> [String: Any] {
            ["id": id, "window": window, "remaining_fraction": fraction,
             "reset_time": "2026-10-17T12:15:13.000Z"]
        }
        var gemini = [bucket("gemini-5h", "5h", geminiFraction)]
        if includeGeminiWeekly { gemini.append(bucket("gemini-weekly", "weekly", 0.6702931523323059)) }
        return try JSONSerialization.data(withJSONObject: [
            "status": status, "num_turns": turns,
            "command": ["name": command, "data": ["groups": [
                ["name": "Gemini Models", "buckets": gemini],
                ["name": "Claude and GPT models", "buckets": [
                    bucket("3p-5h", "5h", 1), bucket("3p-weekly", "weekly", 1),
                ]],
            ]]],
            "response": "ignored free-form content", "conversation_id": "ignored-identity",
        ])
    }
}
