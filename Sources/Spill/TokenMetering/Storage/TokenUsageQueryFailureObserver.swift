import Foundation

/// Records that at least one SQL statement in a multi-query batch failed to prepare or step,
/// so batch callers can discard the whole result instead of publishing silently-defaulted
/// partial data. Reference semantics on purpose: one instance is threaded through every
/// query in a batch.
final class TokenUsageQueryFailureObserver {
    private(set) var didFail = false
    func markFailure() { didFail = true }
}
