import XCTest
@testable import Spill

@MainActor
final class AIStatusStoreTests: XCTestCase {
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
        XCTAssertEqual(store.statuses, [])

        store.refresh()
        XCTAssertEqual(store.statuses.first { $0.kind == .codex }?.value, "Running")
        XCTAssertEqual(store.statuses.first { $0.kind == .openAI }?.value, "Configured")
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
    }
}
