import Combine
import XCTest
@testable import Spill

@MainActor
final class TokenUsageDashboardLimitStoreTests: XCTestCase {
    func testSlowReadDoesNotBlockMainActorAndBurstKeepsOneFollowup() async throws {
        let reader = ControlledLimitReader()
        defer { reader.release.signal() }
        let store = TokenUsageDashboardLimitStore(read: { reader.read() })
        var publications = 0
        let subscription = store.$snapshots.dropFirst().sink { _ in publications += 1 }
        store.refresh()
        // This stays reachable while the background reader is blocked.
        for _ in 0..<100 { store.refresh() }
        reader.release.signal()
        for _ in 0..<100 {
            if store.snapshots.first?.usedPercent == 2 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(store.snapshots.first?.usedPercent, 2)
        XCTAssertEqual(reader.count, 2)
        XCTAssertFalse(reader.ranOnMain)
        XCTAssertEqual(publications, 2)
        reader.useSameResult = true
        store.refresh()
        for _ in 0..<100 {
            if reader.count == 3 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(reader.count, 3)
        XCTAssertEqual(publications, 2)
        withExtendedLifetime(subscription) {}
    }
}

private final class ControlledLimitReader: @unchecked Sendable {
    let release = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var reads = 0
    private var mainThread = false
    private var sameResult = false
    var count: Int { lock.withLock { reads } }
    var ranOnMain: Bool { lock.withLock { mainThread } }
    var useSameResult: Bool {
        get { lock.withLock { sameResult } }
        set { lock.withLock { sameResult = newValue } }
    }
    func read() -> [TokenUsageLimitSnapshot] {
        let (index, fixed) = lock.withLock {
            reads += 1
            mainThread = mainThread || Thread.isMainThread
            return (reads, sameResult)
        }
        if index == 1 { _ = release.wait(timeout: .now() + 2) }
        return [TokenUsageLimitSnapshot(
            aiTool: .codex, limitKey: "primary", label: "Weekly",
            usedPercent: Double(fixed ? 2 : index), remainingCredits: nil,
            windowMinutes: nil, resetsAt: nil,
            capturedAt: Date(timeIntervalSince1970: 1_000), source: .serverExact
        )]
    }
}
