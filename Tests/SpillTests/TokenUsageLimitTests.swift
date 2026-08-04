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
        // The strip honors the tool-hiding setting like every other surface.
        XCTAssertTrue(dashboardView.contains("snapshots: visibleLimitSnapshots"))
        XCTAssertTrue(
            dashboardView.contains(
                "return limitSnapshots.filter { visibleTools.contains($0.aiTool) }"
            )
        )
        XCTAssertFalse(strip.contains("Timer"))
        // Shared ring thresholds: warning at 20% remaining, critical at 5%.
        XCTAssertTrue(strip.contains("remaining <= 5"))
        XCTAssertTrue(strip.contains("remaining <= 20"))
        // Estimated readings carry the mandated tilde prefix.
        XCTAssertTrue(strip.contains(#"source == .estimated ? "~" : """#))
        // Chips render the same fixed window slots on every tool so the
        // basis is comparable: five-hour then weekly, extras behind +n.
        XCTAssertTrue(strip.contains("fiveHourWindowMinutes = 300"))
        XCTAssertTrue(strip.contains("weeklyWindowMinutes = 10_080"))
        XCTAssertTrue(strip.contains("[Self.fiveHourWindowMinutes, Self.weeklyWindowMinutes]"))
        XCTAssertTrue(strip.contains(#"Text("+\(group.extraCount)")"#))
    }

    func testEstimatedWindowMathUsesSlidingHighWaterDenominators() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        func hour(_ offset: Int, _ tokens: Int) -> (hourStart: Date, totalTokens: Int) {
            (base.addingTimeInterval(TimeInterval(offset) * 3_600), tokens)
        }
        // Peak burst: hours 0-4 sum to 500; a quieter recent window sums to 120.
        let hourly = [hour(0, 100), hour(1, 100), hour(2, 100), hour(3, 100), hour(4, 100),
                      hour(20, 40), hour(22, 50), hour(23, 30)]

        XCTAssertEqual(
            TokenUsageEstimatedLimitCapture.maximumWindowTotal(hourly: hourly, windowSeconds: 5 * 3_600),
            500
        )
        let currentWindowEnd = base.addingTimeInterval(23.5 * 3_600)
        XCTAssertEqual(
            TokenUsageEstimatedLimitCapture.windowTotal(
                hourly: hourly,
                startingAt: base.addingTimeInterval(20 * 3_600),
                endingAt: currentWindowEnd
            ),
            120
        )
    }

    func testActiveWindowStartChainsFixedWindowsAndExpires() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        func hour(_ offset: Double, _ tokens: Int) -> (hourStart: Date, totalTokens: Int) {
            (base.addingTimeInterval(offset * 3_600), tokens)
        }
        let fiveHours: TimeInterval = 5 * 3_600
        // First window opens at hour 0 and expires at hour 5; the hour-20
        // bucket opens the next window, which covers hours 20-25.
        let hourly = [hour(0, 100), hour(1, 100), hour(20, 40), hour(23, 30)]

        XCTAssertEqual(
            TokenUsageEstimatedLimitCapture.activeWindowStart(
                hourly: hourly, windowSeconds: fiveHours, endingAt: base.addingTimeInterval(3 * 3_600)
            ),
            base
        )
        XCTAssertEqual(
            TokenUsageEstimatedLimitCapture.activeWindowStart(
                hourly: hourly, windowSeconds: fiveHours, endingAt: base.addingTimeInterval(23.5 * 3_600)
            ),
            base.addingTimeInterval(20 * 3_600)
        )
        // Hours 5-19 and 25+ have no active window: the next turn starts fresh.
        XCTAssertNil(
            TokenUsageEstimatedLimitCapture.activeWindowStart(
                hourly: hourly, windowSeconds: fiveHours, endingAt: base.addingTimeInterval(10 * 3_600)
            )
        )
        XCTAssertNil(
            TokenUsageEstimatedLimitCapture.activeWindowStart(
                hourly: hourly, windowSeconds: fiveHours, endingAt: base.addingTimeInterval(26 * 3_600)
            )
        )
        // Before any usage there is no window either.
        XCTAssertNil(
            TokenUsageEstimatedLimitCapture.activeWindowStart(
                hourly: hourly, windowSeconds: fiveHours, endingAt: base.addingTimeInterval(-1)
            )
        )
    }

    func testClaudeCaptureReadsExactCachedUtilization() {
        let now = Date(timeIntervalSince1970: 1_785_852_800)
        let cache: [String: Any] = [
            "fetchedAtMs": 1_785_852_770_507.0,
            "utilization": [
                "limits": [
                    ["kind": "session", "percent": 13.0, "severity": "normal",
                     "resets_at": "2026-08-04T18:10:00.390172+00:00"],
                    ["kind": "weekly_all", "percent": 30.0,
                     "resets_at": "2026-08-07T18:00:00.390204+00:00"],
                    ["kind": "weekly_scoped", "percent": 29.0,
                     "resets_at": "2026-08-07T18:00:00.390666+00:00",
                     "scope": ["model": ["display_name": "Fable"]]],
                    // Expired windows and unknown kinds are dropped.
                    ["kind": "session", "percent": 99.0,
                     "resets_at": "2026-08-01T00:00:00+00:00"],
                    ["kind": "spend", "percent": 0.0],
                ] as [[String: Any]],
            ] as [String: Any],
        ]

        let snapshots = TokenUsageClaudeLimitCapture.snapshots(
            cachedUsageUtilization: cache,
            now: now
        )
        XCTAssertEqual(snapshots.count, 3)
        XCTAssertTrue(snapshots.allSatisfy { $0.source == .clientCache })
        XCTAssertTrue(snapshots.allSatisfy { $0.aiTool == .claude })
        // capturedAt is the cache's own fetch time, not the read time.
        XCTAssertEqual(
            snapshots.first?.capturedAt.timeIntervalSince1970 ?? 0,
            1_785_852_770.507,
            accuracy: 0.01
        )
        let session = snapshots.first { $0.limitKey == "session_5h" }
        XCTAssertEqual(session?.usedPercent, 13)
        XCTAssertEqual(session?.windowMinutes, 300)
        XCTAssertNotNil(session?.resetsAt)
        let weekly = snapshots.first { $0.limitKey == "week_all" }
        XCTAssertEqual(weekly?.label, "Weekly")
        XCTAssertEqual(weekly?.usedPercent, 30)
        let scoped = snapshots.first { $0.limitKey == "weekly_scoped_fable" }
        XCTAssertEqual(scoped?.label, "Fable")
        XCTAssertEqual(scoped?.windowMinutes, 10_080)

        // Malformed or absent caches produce nothing.
        XCTAssertTrue(
            TokenUsageClaudeLimitCapture.snapshots(cachedUsageUtilization: nil, now: now).isEmpty
        )
        XCTAssertTrue(
            TokenUsageClaudeLimitCapture.snapshots(
                cachedUsageUtilization: ["utilization": ["limits": "nope"]],
                now: now
            ).isEmpty
        )
    }

    func testEstimatedCaptureWritesTildeTaggedGaugesFromRealEvents() throws {
        let eventsURL = temporaryDirectory().appendingPathComponent("events.json")
        let usageStore = TokenUsageStore(fileURL: eventsURL)
        _ = try usageStore.appendEvent(
            TokenUsageLimitTests.claudeEvent(spanID: "span_est_1", totalTokens: 900)
        )
        _ = try usageStore.appendEvent(
            TokenUsageLimitTests.claudeEvent(spanID: "span_est_2", totalTokens: 100)
        )

        let store = TokenUsageLimitSnapshotStore(
            fileURL: temporaryDirectory().appendingPathComponent("limit-snapshots.json")
        )
        let capture = TokenUsageEstimatedLimitCapture(usageStore: usageStore)
        capture.captureEstimates(into: store)

        let claude = store.snapshots(for: .claude)
        XCTAssertEqual(Set(claude.map(\.limitKey)), ["session_5h", "week_all"])
        for snapshot in claude {
            XCTAssertEqual(snapshot.source, .estimated)
            XCTAssertNotNil(snapshot.usedPercent)
        }
        // The five-hour gauge chains fixed windows, so fresh events open an
        // active window with a reset stamp. The weekly gauge is rolling and
        // must never claim a reset date — its anchor is unknowable locally.
        XCTAssertNotNil(claude.first { $0.limitKey == "session_5h" }?.resetsAt)
        XCTAssertNil(claude.first { $0.limitKey == "week_all" }?.resetsAt)
        // Events just landed, so the current window IS the high-water: 0% left.
        XCTAssertEqual(claude.first?.remainingPercent, 0)
        // No AGY events: nothing renders for AGY, and no credits gauge exists
        // anywhere — the state-database value is a sentinel, not a balance.
        XCTAssertTrue(store.snapshots(for: .antigravity).isEmpty)

        // A tool with an exact capture this pass must keep it: skipping
        // prevents the estimate from overwriting the exact snapshots.
        let exact = TokenUsageLimitSnapshot(
            aiTool: .claude, limitKey: "week_all", label: "Weekly",
            usedPercent: 30, remainingCredits: nil, windowMinutes: 10_080,
            resetsAt: nil, capturedAt: Date(), source: .clientCache
        )
        store.replaceSnapshots(for: .claude, with: [exact])
        capture.captureEstimates(into: store, skipping: [.claude])
        XCTAssertEqual(store.snapshots(for: .claude).map(\.source), [.clientCache])
    }

    private static func claudeEvent(spanID: String, totalTokens: Int) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_local_01",
            projectID: "project_global",
            artifactID: "artifact_global",
            runID: "run_local_01",
            spanID: spanID,
            aiTool: .claude,
            taskType: .analysis,
            stage: .implement,
            model: "claude-fable-5",
            inputTokens: totalTokens - 10,
            outputTokens: 10,
            totalTokens: totalTokens,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0, user: 0, history: 0, repoContext: 0,
                toolOutput: 0, generatedOutput: 0, unknown: totalTokens
            ),
            latencyMS: 100,
            createdAt: ISO8601DateFormatter.tokenUsage.string(from: Date())
        )
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
