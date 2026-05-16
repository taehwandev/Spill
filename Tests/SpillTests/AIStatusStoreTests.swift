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
                processNames: readCount == 1 ? [] : ["codex"]
            )
        })

        store.refresh()
        XCTAssertEqual(store.statuses.first { $0.kind == .codex }?.value, "Idle")
        XCTAssertEqual(store.statuses.first { $0.kind == .openAI }?.value, "Missing")

        store.refresh()
        XCTAssertEqual(store.statuses.first { $0.kind == .codex }?.value, "Live")
        XCTAssertEqual(store.statuses.first { $0.kind == .openAI }?.value, "Set")
    }
}
