import Foundation
import XCTest
@testable import Spill

final class TokenUsageCollectorCoordinatorTests: XCTestCase {
    func testDisabledToolsSkipCollectionAndResumeWhenEnabled() async {
        let state = CollectorRaceState()
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let collector = TokenUsageCollectorCoordinator(
            store: store,
            antigravityImportRunner: { _, _, _ in
                state.recordAntigravityRun()
                return Self.emptyAntigravitySummary
            },
            claudeCodeImportRunner: { _, _ in
                state.recordClaudeRun()
                return Self.emptyClaudeSummary
            },
            codexLimitCaptureRunner: { state.recordCodexLimitCapture() },
            claudeLimitCaptureRunner: { state.recordClaudeLimitCapture() },
            antigravityLimitCaptureRunner: { _ in state.recordAntigravityLimitCapture() },
            enabledTools: []
        )

        await collector.requestCollectionAndWait(reason: "manual_refresh")
        XCTAssertEqual(state.snapshot.antigravityRuns, 0)
        XCTAssertEqual(state.snapshot.claudeRuns, 0)
        XCTAssertEqual(state.snapshot.codexLimitCaptures, 0)
        XCTAssertEqual(state.snapshot.claudeLimitCaptures, 0)
        XCTAssertEqual(state.snapshot.antigravityLimitCaptures, 0)

        collector.setEnabledTools([.claude])
        await collector.requestCollectionAndWait(reason: "manual_refresh")
        XCTAssertEqual(state.snapshot.antigravityRuns, 0)
        XCTAssertEqual(state.snapshot.claudeRuns, 1)
        XCTAssertEqual(state.snapshot.codexLimitCaptures, 0)
        XCTAssertEqual(state.snapshot.claudeLimitCaptures, 1)

        collector.setEnabledTools([.antigravity])
        await collector.requestCollectionAndWait(reason: "manual_refresh")
        XCTAssertEqual(state.snapshot.antigravityRuns, 1)
        XCTAssertEqual(state.snapshot.antigravityLimitCaptures, 1)
    }

    func testManualRefreshAcceptedAtFinalizationFinishesAfterItsForcedPass() async throws {
        let state = CollectorRaceState()
        let collectorBox = CollectorBox()
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let collector = TokenUsageCollectorCoordinator(
            store: store,
            antigravityImportRunner: { _, _, _ in
                state.recordAntigravityRun()
                return Self.emptyAntigravitySummary
            },
            claudeCodeImportRunner: { _, _ in
                state.recordClaudeRun()
                return Self.emptyClaudeSummary
            },
            activeImporterMinimumInterval: 60,
            now: { Date(timeIntervalSince1970: 10_000) },
            finalizationBoundaryHook: {
                guard state.claimManualRequest(), let collector = collectorBox.collector else {
                    return
                }
                collector.requestCollection(reason: "manual_refresh") {
                    state.recordManualCompletion()
                }
            },
            antigravityLimitCaptureRunner: { _ in state.recordAntigravityLimitCapture() }
        )
        collectorBox.collector = collector

        collector.requestCollection(reason: "dashboard_refresh")

        for _ in 0..<200 where !state.snapshot.manualCompleted {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let snapshot = state.snapshot
        XCTAssertTrue(snapshot.manualRequested)
        XCTAssertTrue(snapshot.manualCompleted)
        XCTAssertEqual(snapshot.antigravityRuns, 2)
        XCTAssertEqual(snapshot.claudeRuns, 2)
        XCTAssertEqual(snapshot.antigravityLimitCaptures, 2)
        XCTAssertFalse(snapshot.manualCompletionObservedDuringSecondClaudeRun)
    }

    func testAGYLimitsSharePacingAndHiddenToolCancellation() async {
        let state = CollectorRaceState()
        let box = CollectorBox()
        var observedCancellation = false
        let collector = TokenUsageCollectorCoordinator(
            store: TokenUsageStore(fileURL: temporaryEventsURL()),
            antigravityImportRunner: { _, _, _ in Self.emptyAntigravitySummary },
            claudeCodeImportRunner: { _, _ in Self.emptyClaudeSummary },
            activeImporterMinimumInterval: 60,
            now: { Date(timeIntervalSince1970: 10_000) },
            antigravityLimitCaptureRunner: { shouldCancel in
                state.recordAntigravityLimitCapture()
                if state.snapshot.antigravityLimitCaptures == 2 {
                    box.collector?.setEnabledTools([])
                    observedCancellation = shouldCancel()
                }
            },
            enabledTools: [.antigravity]
        )
        box.collector = collector
        await collector.requestCollectionAndWait(reason: "dashboard_refresh")
        await collector.requestCollectionAndWait(reason: "dashboard_refresh")
        XCTAssertEqual(state.snapshot.antigravityLimitCaptures, 1)
        await collector.requestCollectionAndWait(reason: "manual_refresh")
        XCTAssertEqual(state.snapshot.antigravityLimitCaptures, 2)
        XCTAssertTrue(observedCancellation)
        await collector.requestCollectionAndWait(reason: "manual_refresh")
        XCTAssertEqual(state.snapshot.antigravityLimitCaptures, 2)
    }

    private func temporaryEventsURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("events.json")
    }

    private static var emptyAntigravitySummary: TokenUsageAntigravityImportSummary {
        TokenUsageAntigravityImportSummary(
            scannedDatabases: 0,
            scannedGenerationRows: 0,
            parsedUsageEvents: 0,
            importedEvents: 0,
            skippedDuplicateEvents: 0,
            unsupportedRecords: 0,
            splitOutputFallbackEvents: 0,
            cursorAdvancedDatabases: 0,
            failedToWriteEvents: false
        )
    }

    private static var emptyClaudeSummary: TokenUsageClaudeCodeImportSummary {
        TokenUsageClaudeCodeImportSummary(
            scannedFiles: 0,
            parsedTurns: 0,
            importedEvents: 0,
            skippedDuplicateEvents: 0,
            cursorAdvancedFiles: 0,
            failedToWriteEvents: false
        )
    }
}

private final class CollectorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedCollector: TokenUsageCollectorCoordinator?

    var collector: TokenUsageCollectorCoordinator? {
        get { lock.withLock { storedCollector } }
        set { lock.withLock { storedCollector = newValue } }
    }
}

private final class CollectorRaceState: @unchecked Sendable {
    struct Snapshot {
        let manualRequested: Bool
        let manualCompleted: Bool
        let antigravityRuns: Int
        let claudeRuns: Int
        let codexLimitCaptures: Int
        let claudeLimitCaptures: Int
        let antigravityLimitCaptures: Int
        let manualCompletionObservedDuringSecondClaudeRun: Bool
    }

    private let lock = NSLock()
    private var manualRequested = false
    private var manualCompleted = false
    private var antigravityRuns = 0
    private var claudeRuns = 0
    private var codexLimitCaptures = 0
    private var claudeLimitCaptures = 0
    private var antigravityLimitCaptures = 0
    private var manualCompletionObservedDuringSecondClaudeRun = false

    func claimManualRequest() -> Bool {
        lock.withLock {
            guard !manualRequested else { return false }
            manualRequested = true
            return true
        }
    }

    func recordManualCompletion() {
        lock.withLock { manualCompleted = true }
    }

    func recordAntigravityRun() {
        lock.withLock { antigravityRuns += 1 }
    }

    func recordClaudeRun() {
        lock.withLock {
            claudeRuns += 1
            if claudeRuns == 2 {
                manualCompletionObservedDuringSecondClaudeRun = manualCompleted
            }
        }
    }

    func recordCodexLimitCapture() {
        lock.withLock { codexLimitCaptures += 1 }
    }

    func recordClaudeLimitCapture() {
        lock.withLock { claudeLimitCaptures += 1 }
    }

    func recordAntigravityLimitCapture() {
        lock.withLock { antigravityLimitCaptures += 1 }
    }

    var snapshot: Snapshot {
        lock.withLock {
            Snapshot(
                manualRequested: manualRequested,
                manualCompleted: manualCompleted,
                antigravityRuns: antigravityRuns,
                claudeRuns: claudeRuns,
                codexLimitCaptures: codexLimitCaptures,
                claudeLimitCaptures: claudeLimitCaptures,
                antigravityLimitCaptures: antigravityLimitCaptures,
                manualCompletionObservedDuringSecondClaudeRun: manualCompletionObservedDuringSecondClaudeRun
            )
        }
    }
}
