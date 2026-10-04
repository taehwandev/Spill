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
        var readKinds = [Set<LocalAIToolKind>]()
        let store = AIStatusStore(reader: { enabledKinds in
            readCount += 1
            readKinds.append(enabledKinds)
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
        XCTAssertNil(store.statuses.first { $0.kind == .openAI })
        XCTAssertEqual(store.detectedStatuses.map(\.kind), [.codex])
        XCTAssertEqual(readKinds, [
            [.codex, .claude, .antigravity],
            [.codex, .claude, .antigravity],
        ])
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
        let store = AIStatusStore(reader: { _ in
            [claudeStatus, openAIStatus]
        })

        store.refresh()

        XCTAssertEqual(
            store.statuses.map(\.kind),
            [.codex, .claude, .antigravity]
        )
        XCTAssertEqual(store.statuses[1], claudeStatus)
        XCTAssertEqual(store.detectedStatuses, [claudeStatus])
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
        let store = AIStatusStore(reader: { _ in detectedStatuses })

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
            reader: { _ in [] },
            backgroundReader: { _, shouldCancel in
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

    func testDisablingKindsRemovesStatusesAndSkipsSynchronousReads() {
        let codex = LocalAIToolStatus(kind: .codex, value: "Running", subtitle: nil, state: .normal)
        let claude = LocalAIToolStatus(kind: .claude, value: "Running", subtitle: nil, state: .normal)
        var readKinds = [Set<LocalAIToolKind>]()
        let store = AIStatusStore(statuses: [codex, claude], reader: { enabledKinds in
            readKinds.append(enabledKinds)
            return [codex, claude]
        })

        store.setEnabledKinds([.claude])
        XCTAssertEqual(store.statuses.map(\.kind), [.claude])
        XCTAssertEqual(store.detectedStatuses.map(\.kind), [.claude])

        store.refresh()
        XCTAssertEqual(readKinds, [[.claude]])
        XCTAssertEqual(store.statuses.map(\.kind), [.claude])

        store.setEnabledKinds([])
        store.refresh()
        store.refreshInBackground()
        XCTAssertEqual(readKinds.count, 1)
        XCTAssertEqual(store.statuses, [])
        XCTAssertEqual(store.detectedStatuses, [])
    }

    func testChangingEnabledKindsCancelsStaleBackgroundRefresh() async {
        let started = expectation(description: "background reader started")
        let releaseReader = DispatchSemaphore(value: 0)
        let store = AIStatusStore(
            statuses: [],
            reader: { _ in [] },
            backgroundReader: { _, shouldCancel in
                started.fulfill()
                _ = releaseReader.wait(timeout: .now() + 1)
                XCTAssertTrue(shouldCancel())
                return [LocalAIToolStatus(kind: .codex, value: "Running", subtitle: nil, state: .normal)]
            }
        )

        store.refreshInBackground()
        await fulfillment(of: [started], timeout: 1)
        store.setEnabledKinds([.claude])
        releaseReader.signal()

        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(store.statuses.map(\.kind), [.claude])
        XCTAssertEqual(store.detectedStatuses, [])
    }

    func testChangingEnabledKindsClearsBackgroundRefreshInterval() async {
        let firstRefresh = expectation(description: "first background reader started")
        let secondRefresh = expectation(description: "newly enabled reader started immediately")
        let store = AIStatusStore(
            statuses: [],
            reader: { _ in [] },
            backgroundReader: { kinds, _ in
                if kinds.contains(.codex) {
                    firstRefresh.fulfill()
                } else {
                    secondRefresh.fulfill()
                }
                return []
            }
        )

        store.refreshInBackground()
        await fulfillment(of: [firstRefresh], timeout: 1)
        store.setEnabledKinds([.claude])
        store.refreshInBackground()
        await fulfillment(of: [secondRefresh], timeout: 1)
    }
}
