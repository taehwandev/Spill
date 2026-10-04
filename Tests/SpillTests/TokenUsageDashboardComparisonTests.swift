import XCTest
@testable import Spill

final class TokenUsageDashboardComparisonTests: XCTestCase {
    func testFreshOnlyComparesTheSameUsageAsTheHeadline() throws {
        let snapshot = try makeSnapshot(scope: .freshOnly)
        let comparison = try XCTUnwrap(snapshot.usageComparison(for: .freshOnly))

        XCTAssertEqual(snapshot.totalTokens, 1_000)
        XCTAssertEqual(snapshot.usageKPIs(for: .freshOnly, language: .english).first?.value, "100")
        XCTAssertEqual(snapshot.comparisonTotalTokens, 100)
        XCTAssertEqual(comparison.delta, 0)
        XCTAssertEqual(comparison.percentage, 0)
    }

    func testIncludeCacheRetainsTheRawPeriodComparison() throws {
        let snapshot = try makeSnapshot(scope: .includeCache)
        let comparison = try XCTUnwrap(snapshot.usageComparison(for: .includeCache))

        XCTAssertEqual(snapshot.comparisonTotalTokens, 200)
        XCTAssertEqual(comparison.delta, 800)
        XCTAssertEqual(comparison.percentage, 400)
    }

    func testFreshOnlyRetainsAnAlreadyProjectedPreviousTotalAndDecline() throws {
        let snapshot = try makeSnapshot(scope: .freshOnly, previousFreshInput: 180, previousCachedInput: 500)
        let comparison = try XCTUnwrap(snapshot.usageComparison(for: .freshOnly))

        XCTAssertEqual(snapshot.comparisonTotalTokens, 200)
        XCTAssertEqual(comparison.delta, -100)
        XCTAssertEqual(comparison.percentage, -50)
    }

    func testMissingOrZeroPreviousUsageHasNoPercentageComparison() throws {
        let withoutPrevious = try makeSnapshot(scope: .freshOnly, previousFreshInput: nil)
        XCTAssertNil(withoutPrevious.comparisonTotalTokens)
        XCTAssertNil(withoutPrevious.usageComparison(for: .freshOnly))

        let zeroPrevious = try makeSnapshot(
            scope: .freshOnly, previousFreshInput: 0, previousCachedInput: 0, previousOutput: 0
        )
        XCTAssertEqual(zeroPrevious.comparisonTotalTokens, 0)
        XCTAssertNil(zeroPrevious.usageComparison(for: .freshOnly))
    }

    @MainActor
    func testPendingScopeChangeKeepsTheAppliedSnapshotComparisonUntilRebuilt() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let usageStore = TokenUsageStore(fileURL: directory.appendingPathComponent("events.json"))
        try usageStore.replaceEvents(fixtureEvents(now: Date(), calendar: .autoupdatingCurrent))
        let store = TokenUsageDashboardStore(usageStore: usageStore, loadsInitialPanelSummary: false)
        store.refreshAsync(trackLiveUpdates: false, refreshesPanelSummary: false)
        try await waitForRefresh(store)

        store.setUsageInputScope(.freshOnly)
        XCTAssertEqual(store.usageInputScope, .freshOnly)
        XCTAssertEqual(store.snapshotInputScope, .includeCache)
        XCTAssertEqual(store.snapshot.usageComparison(for: store.snapshotInputScope)?.percentage, 400)

        try await waitForRefresh(store)
        XCTAssertEqual(store.snapshotInputScope, .freshOnly)
        XCTAssertEqual(store.snapshot.usageComparison(for: store.snapshotInputScope)?.percentage, 0)
    }

    private func makeSnapshot(
        scope: TokenUsageInputScope,
        previousFreshInput: Int? = 80,
        previousCachedInput: Int = 100,
        previousOutput: Int = 20
    ) throws -> TokenUsageDashboardSnapshot {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-03T12:00:00Z"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        return TokenUsageDashboardSnapshot(
            events: fixtureEvents(
                now: now, calendar: calendar, previousFreshInput: previousFreshInput,
                previousCachedInput: previousCachedInput, previousOutput: previousOutput
            ),
            selectedPeriod: .today, language: .english, now: now, inputScope: scope, calendar: calendar
        )
    }

    private func fixtureEvents(
        now: Date,
        calendar: Calendar,
        previousFreshInput: Int? = 80,
        previousCachedInput: Int = 100,
        previousOutput: Int = 20
    ) -> [TokenUsageEvent] {
        let today = calendar.startOfDay(for: now).addingTimeInterval(3_600)
        var events = [event(id: "today", date: today, freshInput: 80, cachedInput: 900, output: 20)]
        if let previousFreshInput, let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            events.append(event(
                id: "yesterday", date: yesterday, freshInput: previousFreshInput,
                cachedInput: previousCachedInput, output: previousOutput
            ))
        }
        return events
    }

    private func event(id: String, date: Date, freshInput: Int, cachedInput: Int, output: Int) -> TokenUsageEvent {
        let input = freshInput + cachedInput
        return TokenUsageEvent(
            schemaVersion: 1, deviceID: "device_fixture", projectID: "project_fixture",
            artifactID: "artifact_fixture", runID: "run_fixture", spanID: "span_fixture_\(id)",
            aiTool: .claude, taskType: .analysis, stage: .plan, model: "comparison-fixture",
            inputTokens: input, outputTokens: output, totalTokens: input + output,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0, user: 0, history: 0, repoContext: 0, toolOutput: 0,
                generatedOutput: 0, unknown: input + output
            ),
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: freshInput, cacheReadInputTokens: cachedInput),
            latencyMS: 0, createdAt: ISO8601DateFormatter.tokenUsage.string(from: date)
        )
    }

    @MainActor
    private func waitForRefresh(_ store: TokenUsageDashboardStore) async throws {
        for _ in 0..<40 {
            if store.loadState == .loaded, !store.isDashboardRefreshInProgress {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Dashboard comparison refresh did not finish")
    }
}
