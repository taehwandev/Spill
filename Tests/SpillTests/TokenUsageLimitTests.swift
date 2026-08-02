import Foundation
import XCTest
@testable import Spill

final class TokenUsageLimitTests: XCTestCase {
    func testSnapshotStoreRoundTripsAndAgesOutReplacedLimits() throws {
        let fileURL = temporaryDirectory().appendingPathComponent("limit-snapshots.json")
        let store = TokenUsageLimitSnapshotStore(fileURL: fileURL)
        let capturedAt = Date(timeIntervalSince1970: 1_000_000)

        store.replaceSnapshots(for: .codex, with: [
            snapshot(tool: .codex, key: "codex:primary", label: "Weekly", usedPercent: 60, capturedAt: capturedAt),
            snapshot(tool: .codex, key: "spark:primary", label: "Spark Weekly", usedPercent: 0, capturedAt: capturedAt),
        ])
        store.replaceSnapshots(for: .claude, with: [
            snapshot(tool: .claude, key: "session", label: "5-hour", usedPercent: 93, capturedAt: capturedAt),
        ])

        // A fresh instance over the same file sees both tools (cross-process shape).
        let reader = TokenUsageLimitSnapshotStore(fileURL: fileURL)
        XCTAssertEqual(reader.allSnapshots().count, 3)
        XCTAssertEqual(reader.snapshots(for: .codex).count, 2)

        // Replacing Codex with one limit ages out the other and leaves Claude alone.
        store.replaceSnapshots(for: .codex, with: [
            snapshot(tool: .codex, key: "codex:primary", label: "Weekly", usedPercent: 69, capturedAt: capturedAt),
        ])
        XCTAssertEqual(reader.snapshots(for: .codex).map(\.limitKey), ["codex:primary"])
        XCTAssertEqual(reader.snapshots(for: .codex).first?.usedPercent, 69)
        XCTAssertEqual(reader.snapshots(for: .claude).count, 1)
    }

    func testMostConstrainedPicksTheLowestRemainingPercentage() {
        let snapshots = [
            snapshot(tool: .codex, key: "a", label: "Weekly", usedPercent: 60, capturedAt: Date()),
            snapshot(tool: .codex, key: "b", label: "5-hour", usedPercent: 97, capturedAt: Date()),
        ]
        XCTAssertEqual(TokenUsageLimitSnapshotStore.mostConstrained(in: snapshots)?.limitKey, "b")
    }

    func testCodexCaptureParsesNamedLimitsFromSessionTail() throws {
        let sessionsRoot = temporaryDirectory()
        let dayDirectory = sessionsRoot.appendingPathComponent("2026/08/02", isDirectory: true)
        try FileManager.default.createDirectory(at: dayDirectory, withIntermediateDirectories: true)

        let olderLine = rateLimitLine(
            timestamp: "2026-08-02T07:00:00.000Z",
            limitID: "codex",
            usedPercent: 55.5,
            windowMinutes: 10_080,
            resetsAt: 1_786_160_796
        )
        let newerLine = rateLimitLine(
            timestamp: "2026-08-02T08:09:31.676Z",
            limitID: "codex",
            usedPercent: 69.0,
            windowMinutes: 10_080,
            resetsAt: 1_786_160_796
        )
        let sparkLine = rateLimitLine(
            timestamp: "2026-08-02T08:00:00.000Z",
            limitID: "gpt-5.3-codex-spark",
            usedPercent: 0,
            windowMinutes: 10_080,
            resetsAt: 1_786_253_160
        )
        let noise = #"{"timestamp":"2026-08-02T08:09:32.000Z","type":"event_msg","payload":{"type":"agent_message"}}"#
        let contents = [olderLine, sparkLine, noise, newerLine].joined(separator: "\n") + "\n"
        try contents.write(
            to: dayDirectory.appendingPathComponent("session.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let fileURL = sessionsRoot.appendingPathComponent("limit-snapshots.json")
        let store = TokenUsageLimitSnapshotStore(fileURL: fileURL)
        let capture = TokenUsageCodexLimitCapture(
            sessionsDirectory: sessionsRoot,
            now: { Date(timeIntervalSince1970: 2_000_000) }
        )
        capture.captureLatestSnapshots(into: store)

        let captured = store.snapshots(for: .codex).sorted { $0.limitKey < $1.limitKey }
        XCTAssertEqual(captured.map(\.limitKey), ["codex:primary", "gpt-5.3-codex-spark:primary"])

        let weekly = try XCTUnwrap(captured.first { $0.limitKey == "codex:primary" })
        // The newest snapshot per limit wins, not the first one encountered.
        XCTAssertEqual(weekly.usedPercent, 69.0)
        XCTAssertEqual(weekly.remainingPercent, 31.0)
        XCTAssertEqual(weekly.label, "Weekly")
        XCTAssertEqual(weekly.windowMinutes, 10_080)
        XCTAssertEqual(weekly.resetsAt, Date(timeIntervalSince1970: 1_786_160_796))
        XCTAssertEqual(weekly.source, .serverExact)

        let spark = try XCTUnwrap(captured.first { $0.limitKey == "gpt-5.3-codex-spark:primary" })
        XCTAssertEqual(spark.label, "GPT 5.3 Codex Spark Weekly")
        XCTAssertEqual(spark.remainingPercent, 100.0)
    }

    func testDisplayLabelPrefersServerNamesAndHumanizesNamelessLimitIDs() {
        // A server-provided limit_name is already the display name.
        XCTAssertEqual(
            TokenUsageCodexLimitCapture.displayLabel(
                limitID: "codex_bengalfox",
                limitName: "GPT-5.3-Codex-Spark",
                windowMinutes: 10_080
            ),
            "GPT-5.3-Codex-Spark"
        )
        XCTAssertEqual(
            TokenUsageCodexLimitCapture.displayLabel(limitID: "codex", limitName: nil, windowMinutes: 10_080),
            "Weekly"
        )
        XCTAssertEqual(
            TokenUsageCodexLimitCapture.displayLabel(limitID: "codex", limitName: nil, windowMinutes: 300),
            "5-hour"
        )
    }

    func testCodexCaptureSurvivesMissingDirectoryAndMalformedLines() throws {
        let root = temporaryDirectory()
        let store = TokenUsageLimitSnapshotStore(
            fileURL: root.appendingPathComponent("limit-snapshots.json")
        )

        // Missing sessions directory: captures nothing, crashes nothing.
        TokenUsageCodexLimitCapture(
            sessionsDirectory: root.appendingPathComponent("missing", isDirectory: true)
        ).captureLatestSnapshots(into: store)
        XCTAssertTrue(store.allSnapshots().isEmpty)

        // Malformed rate-limit lines are skipped.
        let dayDirectory = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: dayDirectory, withIntermediateDirectories: true)
        try #"{"broken": "rate_limits""#.write(
            to: dayDirectory.appendingPathComponent("bad.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        TokenUsageCodexLimitCapture(sessionsDirectory: dayDirectory)
            .captureLatestSnapshots(into: store)
        XCTAssertTrue(store.allSnapshots().isEmpty)
    }

    func testDashboardIntegratesTheLimitsStripWithPanelSummaryRefresh() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dashboardView = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/Spill/TokenMetering/Dashboard/Screen/TokenMeteringDashboardView.swift"
            ),
            encoding: .utf8
        )
        let strip = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/Spill/TokenMetering/Dashboard/Sections/TokenMeteringDashboardLimitsStrip.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(dashboardView.contains("TokenMeteringDashboardLimitsStrip("))
        // Refresh rides the panel-summary publisher; no dedicated timer.
        XCTAssertTrue(dashboardView.contains(".onReceive(store.$panelSummary)"))
        XCTAssertFalse(strip.contains("Timer"))
        // Shared ring thresholds: warning at 20% remaining, critical at 5%.
        XCTAssertTrue(strip.contains("remaining <= 5"))
        XCTAssertTrue(strip.contains("remaining <= 20"))
        // Estimated readings carry the mandated tilde prefix.
        XCTAssertTrue(strip.contains(#"source == .estimated ? "~" : """#))
    }

    private func snapshot(
        tool: TokenUsageAITool,
        key: String,
        label: String,
        usedPercent: Double,
        capturedAt: Date
    ) -> TokenUsageLimitSnapshot {
        TokenUsageLimitSnapshot(
            aiTool: tool,
            limitKey: key,
            label: label,
            usedPercent: usedPercent,
            remainingCredits: nil,
            windowMinutes: 10_080,
            resetsAt: capturedAt.addingTimeInterval(3_600),
            capturedAt: capturedAt,
            source: .serverExact
        )
    }

    private func rateLimitLine(
        timestamp: String,
        limitID: String,
        usedPercent: Double,
        windowMinutes: Int,
        resetsAt: Int
    ) -> String {
        """
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count",\
        "rate_limits":{"limit_id":"\(limitID)","limit_name":null,\
        "primary":{"used_percent":\(usedPercent),"window_minutes":\(windowMinutes),"resets_at":\(resetsAt)},\
        "secondary":null,"credits":{"has_credits":false,"unlimited":false,"balance":"0"}}}}
        """
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("spill-limit-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
