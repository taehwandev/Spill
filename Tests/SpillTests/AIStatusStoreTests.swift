import Combine
import XCTest
@testable import Spill

@MainActor
final class AIStatusStoreTests: XCTestCase {
    func testBackgroundRefreshUsesModerateProcessScanFloor() {
        XCTAssertEqual(AIStatusStore.minimumBackgroundRefreshInterval, 15)
    }

    func testRefreshUsesInjectedReader() {
        var readCount = 0
        let store = AIStatusStore(reader: {
            readCount += 1
            return LocalAIStatusProvider.statuses(
                environment: readCount == 1 ? [:] : ["OPENAI_BASE_URL": "http://localhost"],
                processNames: readCount == 1 ? [] : ["codex"],
                installedExecutableNames: readCount == 1 ? [] : ["codex"]
            )
        })

        store.refresh()
        XCTAssertEqual(store.statuses.map(\.kind), [.codex, .claude, .antigravity])
        XCTAssertTrue(store.statuses.allSatisfy { $0.value == "Ready" })
        XCTAssertEqual(store.detectedStatuses, [])

        store.refresh()
        XCTAssertEqual(store.statuses.first { $0.kind == .codex }?.value, "Running")
        XCTAssertEqual(store.statuses.first { $0.kind == .openAI }?.value, "Configured")
        XCTAssertEqual(store.detectedStatuses.map(\.kind), [.codex, .openAI])
    }

    func testRefreshKeepsCanonicalAgentOrderAndPreservesDetectedState() {
        let claudeStatus = LocalAIToolStatus(
            kind: .claude,
            value: "Running",
            subtitle: "2 processes",
            state: .active,
            metadata: LocalAIToolMetadata(
                model: "claude-opus",
                version: "2.1.209",
                source: "Command"
            ),
            processSummary: LocalAIProcessSummary(
                processes: [],
                fallbackProcessCount: 2
            )
        )
        let openAIStatus = LocalAIToolStatus(
            kind: .openAI,
            value: "Configured",
            subtitle: "Environment",
            state: .normal
        )
        let store = AIStatusStore(reader: {
            [claudeStatus, openAIStatus]
        })

        store.refresh()

        XCTAssertEqual(
            store.statuses.map(\.kind),
            [.codex, .claude, .antigravity, .openAI]
        )
        XCTAssertEqual(store.statuses[1], claudeStatus)
        XCTAssertEqual(store.detectedStatuses, [claudeStatus, openAIStatus])
        XCTAssertEqual(
            TokenMeteringToolAvailability.installedTools(from: store.detectedStatuses),
            [.claude]
        )
    }

    func testRepeatedIdenticalRefreshDoesNotPublishStatusStateAgain() {
        let detectedStatuses = LocalAIStatusProvider.statuses(
            environment: ["OPENAI_BASE_URL": "http://localhost"],
            processNames: ["codex"],
            installedExecutableNames: ["codex"]
        )
        let store = AIStatusStore(reader: { detectedStatuses })

        store.refresh()

        var publicationCount = 0
        let cancellable = store.objectWillChange.sink {
            publicationCount += 1
        }

        store.refresh()

        XCTAssertEqual(publicationCount, 0)
        withExtendedLifetime(cancellable) {}
    }

    func testCancelRefreshPreventsBackgroundStatusUpdate() async {
        let started = expectation(description: "background reader started")
        let releaseReader = DispatchSemaphore(value: 0)
        let store = AIStatusStore(
            statuses: [],
            reader: { [] },
            backgroundReader: { shouldCancel in
                started.fulfill()
                _ = releaseReader.wait(timeout: .now() + 1)
                XCTAssertTrue(shouldCancel())
                return LocalAIStatusProvider.statuses(
                    environment: ["OPENAI_BASE_URL": "http://localhost"],
                    processNames: []
                )
            }
        )

        store.refreshInBackground()
        await fulfillment(of: [started], timeout: 1)
        store.cancelRefresh()
        releaseReader.signal()

        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(store.statuses, [])
        XCTAssertEqual(store.detectedStatuses, [])
    }
}
