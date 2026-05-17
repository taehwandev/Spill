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
        XCTAssertEqual(store.statuses.first { $0.kind == .codex }?.value, "Active")
        XCTAssertEqual(store.statuses.first { $0.kind == .openAI }?.value, "Set")
    }
}
