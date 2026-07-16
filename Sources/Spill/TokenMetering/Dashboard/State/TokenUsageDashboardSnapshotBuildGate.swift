import Foundation

final class TokenUsageDashboardSnapshotBuildGate: @unchecked Sendable {
    private let lock = NSLock()
    private var generation = 0

    @discardableResult
    func next() -> Int {
        lock.withLock {
            generation += 1
            return generation
        }
    }

    func isCurrent(_ candidate: Int) -> Bool {
        lock.withLock {
            generation == candidate
        }
    }
}
