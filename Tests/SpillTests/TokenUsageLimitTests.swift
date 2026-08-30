import Foundation
import XCTest
@testable import Spill

final class TokenUsageLimitTests: XCTestCase {
    func testSnapshotStoreRoundTripsAndMergesPerLimitInsteadOfReplacing() throws {
        let fileURL = temporaryDirectory().appendingPathComponent("limit-snapshots.json")
        let capturedAt = Date(timeIntervalSince1970: 1_000_000)
        let clock = { capturedAt.addingTimeInterval(60) }
        let store = TokenUsageLimitSnapshotStore(fileURL: fileURL, now: clock)

        store.mergeSnapshots(for: .codex, with: [
            snapshot(tool: .codex, key: "codex:primary", label: "Weekly", usedPercent: 60, capturedAt: capturedAt),
            snapshot(tool: .codex, key: "spark:primary", label: "Spark Weekly", usedPercent: 0, capturedAt: capturedAt),
        ])
        store.mergeSnapshots(for: .claude, with: [
            snapshot(tool: .claude, key: "session", label: "5-hour", usedPercent: 93, capturedAt: capturedAt),
        ])

        // A fresh instance over the same file sees both tools (cross-process shape).
        let reader = TokenUsageLimitSnapshotStore(fileURL: fileURL, now: clock)
        XCTAssertEqual(reader.allSnapshots().count, 3)
        XCTAssertEqual(reader.snapshots(for: .codex).count, 2)

        // A pass that only reports one Codex limit updates that limit and
        // leaves the other standing. Whole-set replacement used to delete it,
        // which is what made the chip flicker between windows.
        store.mergeSnapshots(for: .codex, with: [
            snapshot(tool: .codex, key: "codex:primary", label: "Weekly", usedPercent: 69, capturedAt: capturedAt),
        ])
        XCTAssertEqual(
            reader.snapshots(for: .codex).map(\.limitKey).sorted(),
            ["codex:primary", "spark:primary"]
        )
        XCTAssertEqual(
            reader.snapshots(for: .codex).first { $0.limitKey == "codex:primary" }?.usedPercent,
            69
        )
        XCTAssertEqual(reader.snapshots(for: .claude).count, 1)

        // An empty capture changes nothing at all.
        store.mergeSnapshots(for: .codex, with: [])
        XCTAssertEqual(reader.snapshots(for: .codex).count, 2)

        // Explicit replacement is still available for a deliberate reset.
        store.replaceSnapshots(for: .codex, with: [])
        XCTAssertTrue(reader.snapshots(for: .codex).isEmpty)
        XCTAssertEqual(reader.snapshots(for: .claude).count, 1)
    }

    func testLimitsAgeOutOnTheirOwnRetentionClock() throws {
        let fileURL = temporaryDirectory().appendingPathComponent("limit-snapshots.json")
        let capturedAt = Date(timeIntervalSince1970: 1_000_000)
        var clockValue = capturedAt
        let store = TokenUsageLimitSnapshotStore(fileURL: fileURL, now: { clockValue })

        let weekly = snapshot(
            tool: .codex, key: "codex:primary", label: "Weekly",
            usedPercent: 60, capturedAt: capturedAt
        )
        store.mergeSnapshots(for: .codex, with: [weekly])

        // Retention for a weekly window is two windows; a quiet fortnight is
        // still inside it, so an unused tool keeps its chip.
        clockValue = capturedAt.addingTimeInterval(13 * 24 * 3_600)
        XCTAssertEqual(store.snapshots(for: .codex).count, 1)

        // Past that, the limit no longer describes the account.
        clockValue = capturedAt.addingTimeInterval(15 * 24 * 3_600)
        XCTAssertTrue(store.snapshots(for: .codex).isEmpty)
    }

    func testFreshExactReadingOutranksAnEstimateUntilItsWindowPasses() throws {
        let fileURL = temporaryDirectory().appendingPathComponent("limit-snapshots.json")
        let capturedAt = Date(timeIntervalSince1970: 1_000_000)
        var clockValue = capturedAt
        let store = TokenUsageLimitSnapshotStore(fileURL: fileURL, now: { clockValue })

        func gauge(_ source: TokenUsageLimitSnapshot.Source, _ used: Double, at moment: Date)
            -> TokenUsageLimitSnapshot {
            TokenUsageLimitSnapshot(
                aiTool: .claude, limitKey: "session_5h", label: "5-hour",
                usedPercent: used, remainingCredits: nil, windowMinutes: 300,
                resetsAt: nil, capturedAt: moment, source: source
            )
        }

        store.mergeSnapshots(for: .claude, with: [gauge(.clientCache, 40, at: capturedAt)])

        // The client cache went missing for one pass: an estimate must not
        // downgrade a server number that still describes the open window.
        clockValue = capturedAt.addingTimeInterval(3_600)
        store.mergeSnapshots(for: .claude, with: [gauge(.estimated, 90, at: clockValue)])
        XCTAssertEqual(store.snapshots(for: .claude).first?.source, .clientCache)
        XCTAssertEqual(store.snapshots(for: .claude).first?.usedPercent, 40)

        // Once the exact reading outlives its own window it cannot describe the
        // current one, so the estimate takes over.
        clockValue = capturedAt.addingTimeInterval(6 * 3_600)
        store.mergeSnapshots(for: .claude, with: [gauge(.estimated, 90, at: clockValue)])
        XCTAssertEqual(store.snapshots(for: .claude).first?.source, .estimated)

        // An exact reading always reclaims the slot.
        store.mergeSnapshots(for: .claude, with: [gauge(.clientCache, 12, at: clockValue)])
        XCTAssertEqual(store.snapshots(for: .claude).first?.source, .clientCache)
    }

    func testClosedWindowResolvesToResetInsteadOfDisappearing() throws {
        let fileURL = temporaryDirectory().appendingPathComponent("limit-snapshots.json")
        let capturedAt = Date(timeIntervalSince1970: 1_000_000)
        let resetsAt = capturedAt.addingTimeInterval(2 * 3_600)
        var clockValue = capturedAt
        let store = TokenUsageLimitSnapshotStore(fileURL: fileURL, now: { clockValue })

        store.mergeSnapshots(for: .claude, with: [
            TokenUsageLimitSnapshot(
                aiTool: .claude, limitKey: "session_5h", label: "5-hour",
                usedPercent: 93, remainingCredits: nil, windowMinutes: 300,
                resetsAt: resetsAt, capturedAt: capturedAt, source: .clientCache
            )
        ])

        // Inside the window the stored reading stands unchanged.
        clockValue = capturedAt.addingTimeInterval(3_600)
        let open = try XCTUnwrap(store.snapshots(for: .claude).first)
        XCTAssertEqual(open.usedPercent, 93)
        XCTAssertFalse(open.locallyReset)

        // After the reset moment the allowance is known to be full again. The
        // gauge stays on the chip instead of vanishing, is stamped at the reset
        // moment rather than at capture time, and claims no next reset because
        // a session window opens on first use, not on a clock.
        clockValue = resetsAt.addingTimeInterval(600)
        let reset = try XCTUnwrap(store.snapshots(for: .claude).first)
        XCTAssertEqual(reset.usedPercent, 0)
        XCTAssertEqual(reset.remainingPercent, 100)
        XCTAssertTrue(reset.locallyReset)
        XCTAssertNil(reset.resetsAt)
        XCTAssertEqual(reset.capturedAt, resetsAt)
        // The file itself keeps the raw reading; only the read is resolved.
        XCTAssertEqual(store.storedSnapshots().first?.usedPercent, 93)
    }

    func testSnapshotFilesWrittenBeforeTheResetFlagStillDecode() throws {
        let fileURL = temporaryDirectory().appendingPathComponent("limit-snapshots.json")
        let capturedAt = Date(timeIntervalSince1970: 1_000_000)
        // Exactly the shape already sitting on users' disks: no locallyReset key.
        let legacy = #"""
        [{"aiTool":"codex","capturedAt":"1970-01-12T13:46:40Z","label":"Weekly","limitKey":"codex:primary","resetsAt":"1970-01-12T14:46:40Z","source":"server_exact","usedPercent":2,"windowMinutes":10080}]
        """#
        try legacy.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = TokenUsageLimitSnapshotStore(
            fileURL: fileURL,
            now: { capturedAt.addingTimeInterval(60) }
        )
        let restored = try XCTUnwrap(store.storedSnapshots().first)
        XCTAssertEqual(restored.limitKey, "codex:primary")
        XCTAssertEqual(restored.usedPercent, 2)
        XCTAssertFalse(restored.locallyReset)
        // And the upgraded reader merges onto it rather than dropping it.
        store.mergeSnapshots(for: .codex, with: [
            snapshot(tool: .codex, key: "codex:secondary", label: "5-hour", usedPercent: 10, capturedAt: capturedAt),
        ])
        XCTAssertEqual(store.snapshots(for: .codex).count, 2)
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
        let store = TokenUsageLimitSnapshotStore(
            fileURL: fileURL,
            now: { Date(timeIntervalSince1970: 2_000_000) }
        )
        let capture = TokenUsageCodexLimitCapture(sessionsDirectory: sessionsRoot)
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
        // capturedAt is the moment the reading was true — the session line's own
        // timestamp — not the moment Spill scanned the file. Stamping the scan
        // time made every Codex gauge look permanently fresh however long ago
        // Codex last ran, defeating the as-of display.
        // The store's ISO-8601 encoding drops sub-second precision, so compare
        // to the second.
        let lineTimestamp = try XCTUnwrap(
            ISO8601DateFormatter.parseTokenUsageDate(from: "2026-08-02T08:09:31.676Z")
        )
        XCTAssertEqual(
            weekly.capturedAt.timeIntervalSince1970,
            lineTimestamp.timeIntervalSince1970,
            accuracy: 1
        )

        let spark = try XCTUnwrap(captured.first { $0.limitKey == "gpt-5.3-codex-spark:primary" })
        XCTAssertEqual(spark.label, "GPT 5.3 Codex Spark")
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
        XCTAssertEqual(
            TokenUsageCodexLimitCapture.displayLabel(
                limitID: "gpt-5.3-codex-spark",
                limitName: nil,
                windowMinutes: 10_080
            ),
            "GPT 5.3 Codex Spark"
        )
    }

    func testCodexCaptureRetiresMissingSiblingInsideACompleteLimitGroup() throws {
        let sessionsRoot = temporaryDirectory()
        let sessionURL = sessionsRoot.appendingPathComponent("session.jsonl")
        let initialOverall = rateLimitLine(
            timestamp: "2026-08-02T08:00:00.000Z",
            limitID: "codex",
            usedPercent: 30,
            windowMinutes: 10_080,
            resetsAt: 1_786_160_796,
            secondaryUsedPercent: 40,
            secondaryWindowMinutes: 300,
            secondaryResetsAt: 1_786_125_196
        )
        let independentNamedPool = rateLimitLine(
            timestamp: "2026-08-02T08:01:00.000Z",
            limitID: "gpt-5.3-codex-spark",
            usedPercent: 10,
            windowMinutes: 10_080,
            resetsAt: 1_786_253_160
        )
        try [initialOverall, independentNamedPool].joined(separator: "\n").write(
            to: sessionURL,
            atomically: true,
            encoding: .utf8
        )

        let now = try XCTUnwrap(
            ISO8601DateFormatter.parseTokenUsageDate(from: "2026-08-02T08:03:00.000Z")
        )
        let store = TokenUsageLimitSnapshotStore(
            fileURL: sessionsRoot.appendingPathComponent("limit-snapshots.json"),
            now: { now }
        )
        let capture = TokenUsageCodexLimitCapture(sessionsDirectory: sessionsRoot)
        capture.captureLatestSnapshots(into: store)
        XCTAssertEqual(
            Set(store.snapshots(for: .codex).map(\.limitKey)),
            ["codex:primary", "codex:secondary", "gpt-5.3-codex-spark:primary"]
        )

        // The next overall payload is complete for `limit_id = codex` and says
        // secondary is absent. That must retire only the old overall sibling;
        // the independent named pool remains untouched.
        let weeklyOnlyOverall = rateLimitLine(
            timestamp: "2026-08-02T08:02:00.000Z",
            limitID: "codex",
            usedPercent: 31,
            windowMinutes: 10_080,
            resetsAt: 1_786_160_796
        )
        try [initialOverall, independentNamedPool, weeklyOnlyOverall].joined(separator: "\n").write(
            to: sessionURL,
            atomically: true,
            encoding: .utf8
        )
        capture.captureLatestSnapshots(into: store)

        XCTAssertEqual(
            Set(store.snapshots(for: .codex).map(\.limitKey)),
            ["codex:primary", "gpt-5.3-codex-spark:primary"]
        )
        XCTAssertEqual(
            store.snapshots(for: .codex).first { $0.limitKey == "codex:primary" }?.usedPercent,
            31
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
        // Slots come from the windows in the data, never from a hardcoded
        // five-hour/weekly pair, and extras stay behind +n.
        XCTAssertFalse(strip.contains("fiveHourWindowMinutes"))
        XCTAssertFalse(strip.contains("weeklyWindowMinutes"))
        XCTAssertTrue(strip.contains("Dictionary(grouping: windowed) { $0.windowMinutes ?? 0 }"))
        XCTAssertTrue(strip.contains(#"Text("+\(group.extraCount)")"#))
        // Every chip can state how old its reading is, because no source here
        // refreshes on its own.
        XCTAssertTrue(strip.contains("limitsAge("))
        XCTAssertTrue(strip.contains("group.age > Self.staleThreshold"))
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
                    // An already-closed window is kept, not dropped: the store
                    // resolves it to its post-reset value so the gauge stays.
                    ["kind": "session", "percent": 99.0,
                     "resets_at": "2026-08-01T00:00:00+00:00"],
                    // A kind nobody has shipped yet still becomes a gauge, so a
                    // rename degrades to "listed in the popover", not to gone.
                    ["kind": "weekly_burst", "percent": 4.0,
                     "resets_at": "2026-08-07T18:00:00+00:00"],
                    // No reset moment: a spend or credit row, not a window.
                    ["kind": "spend", "percent": 0.0],
                ] as [[String: Any]],
            ] as [String: Any],
        ]

        let snapshots = TokenUsageClaudeLimitCapture.snapshots(
            cachedUsageUtilization: cache,
            now: now
        )
        XCTAssertEqual(snapshots.count, 5)
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
        XCTAssertTrue(scoped?.isScopedVariant ?? false)
        // An unrecognised window claims no window length, so it never takes a
        // chip slot it might not belong in.
        let unknown = snapshots.first { $0.limitKey == "kind_weekly_burst" }
        XCTAssertEqual(unknown?.label, "Weekly Burst")
        XCTAssertNil(unknown?.windowMinutes)
        // The spend row has no reset moment and is not a window gauge.
        XCTAssertNil(snapshots.first { $0.label.lowercased().contains("spend") })

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

    func testClaudeCaptureFindsTheUtilizationPayloadAfterAKeyRename() throws {
        let root = temporaryDirectory()
        let stateFileURL = root.appendingPathComponent("state.json")
        let diagnosticsURL = root.appendingPathComponent("claude-limit-capture-last.json")
        let now = Date(timeIntervalSince1970: 1_785_852_800)

        // The client renamed the key and dropped the `utilization` nesting.
        // Nothing about the reading itself changed, so Spill must still find it
        // instead of silently falling back to estimated gauges.
        let state: [String: Any] = [
            "unrelatedCache": ["limits": ["not", "usage"]],
            "renamedUsageCache": [
                "fetchedAtMs": 1_785_852_770_000.0,
                "limits": [
                    ["kind": "session", "percent": 21.0,
                     "resets_at": "2026-08-04T18:10:00+00:00"],
                ] as [[String: Any]],
            ] as [String: Any],
        ]
        try JSONSerialization.data(withJSONObject: state).write(to: stateFileURL)

        let store = TokenUsageLimitSnapshotStore(fileURL: root.appendingPathComponent("snapshots.json"), now: { now })
        let capture = TokenUsageClaudeLimitCapture(
            stateFileURL: stateFileURL,
            diagnostics: TokenUsageLimitCaptureDiagnostics(fileURL: diagnosticsURL, now: { now }),
            now: { now }
        )
        XCTAssertTrue(capture.captureLatestSnapshots(into: store))
        XCTAssertEqual(store.snapshots(for: .claude).first?.usedPercent, 21)

        // The diagnostic records that the payload moved, and carries nothing
        // but fixed booleans, counts, and a timestamp.
        let diagnostic = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: diagnosticsURL)) as? [String: Any]
        )
        XCTAssertEqual(diagnostic["utilization_found"] as? Bool, true)
        XCTAssertEqual(diagnostic["found_by_structural_scan"] as? Bool, true)
        XCTAssertEqual(diagnostic["limit_entry_count"] as? Int, 1)
        XCTAssertEqual(diagnostic["windowed_limit_count"] as? Int, 1)
        XCTAssertEqual(
            Set(diagnostic.keys),
            [
                "schema_version", "ai_tool", "kind", "created_at",
                "state_file_found", "state_file_parsed", "utilization_found",
                "found_by_structural_scan", "limit_entry_count",
                "windowed_limit_count", "privacy",
            ]
        )
    }

    func testClaudeCaptureRecordsAMissingExactSourceInsteadOfFailingSilently() throws {
        let root = temporaryDirectory()
        let stateFileURL = root.appendingPathComponent("state.json")
        let diagnosticsURL = root.appendingPathComponent("claude-limit-capture-last.json")
        let now = Date(timeIntervalSince1970: 1_785_852_800)

        // A real state file with no usage payload anywhere in it: exactly the
        // shape that quietly demoted every Claude gauge to an estimate.
        try JSONSerialization
            .data(withJSONObject: ["clientDataCacheSlots": ["slot": ["data": ["flag": true]]]])
            .write(to: stateFileURL)

        let store = TokenUsageLimitSnapshotStore(fileURL: root.appendingPathComponent("snapshots.json"), now: { now })
        let capture = TokenUsageClaudeLimitCapture(
            stateFileURL: stateFileURL,
            diagnostics: TokenUsageLimitCaptureDiagnostics(fileURL: diagnosticsURL, now: { now }),
            now: { now }
        )
        XCTAssertFalse(capture.captureLatestSnapshots(into: store))
        XCTAssertTrue(store.snapshots(for: .claude).isEmpty)

        let diagnostic = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: diagnosticsURL)) as? [String: Any]
        )
        XCTAssertEqual(diagnostic["state_file_found"] as? Bool, true)
        XCTAssertEqual(diagnostic["state_file_parsed"] as? Bool, true)
        XCTAssertEqual(diagnostic["utilization_found"] as? Bool, false)
        XCTAssertEqual(diagnostic["windowed_limit_count"] as? Int, 0)

        // A missing state file is recorded too, and is not the same finding.
        let missingDiagnosticsURL = root.appendingPathComponent("missing.json")
        _ = TokenUsageClaudeLimitCapture(
            stateFileURL: root.appendingPathComponent("absent.json"),
            diagnostics: TokenUsageLimitCaptureDiagnostics(fileURL: missingDiagnosticsURL, now: { now }),
            now: { now }
        ).captureLatestSnapshots(into: store)
        let missing = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: missingDiagnosticsURL)) as? [String: Any]
        )
        XCTAssertEqual(missing["state_file_found"] as? Bool, false)
    }

    func testChipSlotsFollowTheWindowsPresentInTheData() {
        let capturedAt = Date(timeIntervalSince1970: 1_000_000)
        func gauge(_ key: String, _ label: String, _ used: Double, _ minutes: Int?)
            -> TokenUsageLimitSnapshot {
            TokenUsageLimitSnapshot(
                aiTool: .codex, limitKey: key, label: label, usedPercent: used,
                remainingCredits: nil, windowMinutes: minutes, resetsAt: nil,
                capturedAt: capturedAt, source: .serverExact
            )
        }

        // A plan whose only window is weekly renders one slot, not an empty
        // five-hour placeholder: Codex sends `secondary: null` for those plans.
        let weeklyOnly = [gauge("codex:primary", "Weekly", 2, 10_080)]
        XCTAssertEqual(
            TokenMeteringDashboardLimitsStrip.slotGauges(in: weeklyOnly).map(\.limitKey),
            ["codex:primary"]
        )

        // Both windows present: shortest first, so chips stay comparable.
        let both = [
            gauge("codex:primary", "5-hour", 40, 300),
            gauge("codex:secondary", "Weekly", 2, 10_080),
        ]
        XCTAssertEqual(
            TokenMeteringDashboardLimitsStrip.slotGauges(in: both).map(\.limitKey),
            ["codex:primary", "codex:secondary"]
        )

        // A window length nobody hardcoded still takes a slot.
        let daily = [gauge("codex:daily", "Daily", 10, 1_440)]
        XCTAssertEqual(
            TokenMeteringDashboardLimitsStrip.slotGauges(in: daily).map(\.limitKey),
            ["codex:daily"]
        )

        // Only two slots exist; the third window falls behind +n.
        let three = [
            gauge("a", "5-hour", 10, 300),
            gauge("b", "Daily", 10, 1_440),
            gauge("c", "Weekly", 10, 10_080),
        ]
        XCTAssertEqual(
            TokenMeteringDashboardLimitsStrip.slotGauges(in: three).map(\.limitKey),
            ["a", "b"]
        )

        // A gauge with no window length never takes a slot.
        let unwindowed = [gauge("kind_weekly_burst", "Weekly Burst", 4, nil)]
        XCTAssertTrue(TokenMeteringDashboardLimitsStrip.slotGauges(in: unwindowed).isEmpty)
    }

    func testSharedWindowPrefersTheUnscopedLimitThenTheTightestOne() {
        let capturedAt = Date(timeIntervalSince1970: 1_000_000)
        func weekly(_ tool: TokenUsageAITool, _ key: String, _ used: Double)
            -> TokenUsageLimitSnapshot {
            TokenUsageLimitSnapshot(
                aiTool: tool, limitKey: key, label: key, usedPercent: used,
                remainingCredits: nil, windowMinutes: 10_080, resetsAt: nil,
                capturedAt: capturedAt, source: .clientCache
            )
        }

        // The model-scoped weekly is tighter, but the plain weekly represents
        // the slot so the chip means the same thing on every tool.
        let claude = [weekly(.claude, "week_all", 30), weekly(.claude, "weekly_scoped_fable", 71)]
        XCTAssertEqual(
            TokenMeteringDashboardLimitsStrip.representative(of: claude)?.limitKey,
            "week_all"
        )

        // Codex named pools are scoped too. The general account weekly remains
        // the representative even when a separate Spark pool is tighter.
        let codex = [weekly(.codex, "codex:primary", 20), weekly(.codex, "spark:primary", 90)]
        XCTAssertEqual(
            TokenMeteringDashboardLimitsStrip.representative(of: codex)?.limitKey,
            "codex:primary"
        )
        XCTAssertFalse(codex[0].isScopedVariant)
        XCTAssertTrue(codex[1].isScopedVariant)
    }

    func testChipTextRendersTheValueSourceAndResetAUserActuallyReads() throws {
        let strip = TokenMeteringDashboardLimitsStrip(snapshots: [], language: .english)
        let resetsAt = Date(timeIntervalSince1970: 1_000_000)

        // Exact server reading: no tilde, window label from the number.
        let exact = TokenUsageLimitSnapshot(
            aiTool: .codex, limitKey: "codex:primary", label: "Weekly",
            usedPercent: 7, remainingCredits: nil, windowMinutes: 10_080,
            resetsAt: resetsAt, capturedAt: resetsAt, source: .serverExact
        )
        XCTAssertTrue(strip.gaugeText(for: exact).hasPrefix("Wk 93%"))

        // Estimated reading carries the mandated tilde.
        let estimated = TokenUsageLimitSnapshot(
            aiTool: .claude, limitKey: "session_5h", label: "5-hour",
            usedPercent: 27.9, remainingCredits: nil, windowMinutes: 300,
            resetsAt: nil, capturedAt: resetsAt, source: .estimated
        )
        XCTAssertEqual(strip.gaugeText(for: estimated), "5h ~72%")

        // Remaining percent floors rather than rounds, so 99.8% never reads 100.
        let nearlyFull = TokenUsageLimitSnapshot(
            aiTool: .claude, limitKey: "week_all", label: "Weekly",
            usedPercent: 0.2, remainingCredits: nil, windowMinutes: 10_080,
            resetsAt: nil, capturedAt: resetsAt, source: .clientCache
        )
        XCTAssertEqual(strip.gaugeText(for: nearlyFull), "Wk 99%")

        // A locally reset window reads as replenished and claims no reset stamp.
        let reset = TokenUsageLimitSnapshot(
            aiTool: .claude, limitKey: "session_5h", label: "5-hour",
            usedPercent: 93, remainingCredits: nil, windowMinutes: 300,
            resetsAt: resetsAt, capturedAt: resetsAt.addingTimeInterval(-3_600),
            source: .clientCache
        ).resolved(at: resetsAt.addingTimeInterval(600))
        XCTAssertEqual(strip.gaugeText(for: reset), "5h 100%")

        // A limit with no window length falls back to its own label.
        let unwindowed = TokenUsageLimitSnapshot(
            aiTool: .claude, limitKey: "kind_weekly_burst", label: "Weekly Burst",
            usedPercent: 4, remainingCredits: nil, windowMinutes: nil,
            resetsAt: nil, capturedAt: resetsAt, source: .clientCache
        )
        XCTAssertEqual(strip.gaugeText(for: unwindowed), "Weekly Burst 96%")

        // A named Codex pool that is the only weekly reading keeps its identity
        // in the compact slot instead of masquerading as the overall Wk pool.
        let namedCodexPool = TokenUsageLimitSnapshot(
            aiTool: .codex, limitKey: "gpt-5.3-codex-spark:primary",
            label: "GPT-5.3-Codex-Spark", usedPercent: 0,
            remainingCredits: nil, windowMinutes: 10_080, resetsAt: nil,
            capturedAt: resetsAt, source: .serverExact
        )
        XCTAssertEqual(
            strip.gaugeText(for: namedCodexPool),
            "GPT-5.3-Codex-Spark Wk 100%"
        )
    }

    func testWindowAndAgeLabelsAreDerivedFromTheNumbers() {
        XCTAssertEqual(TokenMeteringDashboardLimitsStrip.slotLabel(windowMinutes: 300), "5h")
        XCTAssertEqual(TokenMeteringDashboardLimitsStrip.slotLabel(windowMinutes: 10_080), "Wk")
        XCTAssertEqual(TokenMeteringDashboardLimitsStrip.slotLabel(windowMinutes: 1_440), "1d")
        XCTAssertEqual(TokenMeteringDashboardLimitsStrip.slotLabel(windowMinutes: 20_160), "2w")
        XCTAssertEqual(TokenMeteringDashboardLimitsStrip.slotLabel(windowMinutes: 90), "90m")
        XCTAssertNil(TokenMeteringDashboardLimitsStrip.slotLabel(windowMinutes: nil))

        XCTAssertEqual(TokenMeteringDashboardLimitsStrip.compactDuration(30), "1m")
        XCTAssertEqual(TokenMeteringDashboardLimitsStrip.compactDuration(45 * 60), "45m")
        XCTAssertEqual(TokenMeteringDashboardLimitsStrip.compactDuration(3 * 3_600), "3h")
        XCTAssertEqual(TokenMeteringDashboardLimitsStrip.compactDuration(50 * 3_600), "2d")
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
        resetsAt: Int,
        secondaryUsedPercent: Double? = nil,
        secondaryWindowMinutes: Int = 300,
        secondaryResetsAt: Int = 0
    ) -> String {
        let secondary = secondaryUsedPercent.map {
            "{\"used_percent\":\($0),\"window_minutes\":\(secondaryWindowMinutes),\"resets_at\":\(secondaryResetsAt)}"
        } ?? "null"
        return """
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count",\
        "rate_limits":{"limit_id":"\(limitID)","limit_name":null,\
        "primary":{"used_percent":\(usedPercent),"window_minutes":\(windowMinutes),"resets_at":\(resetsAt)},\
        "secondary":\(secondary),"credits":{"has_credits":false,"unlimited":false,"balance":"0"}}}}
        """
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("spill-limit-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
