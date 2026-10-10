import Darwin
import Foundation

struct TokenUsageAntigravityLimitCapture {
    typealias Runner = (@escaping () -> Bool) -> Data?
    private let runner: Runner
    private let now: () -> Date
    private let lockURL: URL
    private let reuseInterval: TimeInterval

    init(
        runner: @escaping Runner = TokenUsageAntigravityQuotaCommand.output,
        now: @escaping () -> Date = Date.init,
        lockURL: URL = TokenUsageLimitSnapshotStore.defaultFileURL()
            .deletingLastPathComponent().appendingPathComponent(".agy-quota-capture.lock"),
        reuseInterval: TimeInterval = 15
    ) {
        self.runner = runner
        self.now = now
        self.lockURL = lockURL
        self.reuseInterval = reuseInterval
    }

    func captureLatestSnapshots(
        into store: TokenUsageLimitSnapshotStore,
        shouldCancel: @escaping () -> Bool = { false }
    ) {
        guard !shouldCancel() else { return }
        try? FileManager.default.createDirectory(
            at: lockURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let fd = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { return }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { return }
        defer { flock(fd, LOCK_UN) }
        if let latest = store.storedSnapshots()
            .filter({ $0.aiTool == .antigravity && $0.limitKey.hasPrefix("agy_quota:") })
            .map(\.capturedAt).max() {
            let age = now().timeIntervalSince(latest)
            if age >= 0, age < reuseInterval { return }
        }
        guard let data = runner(shouldCancel), !shouldCancel() else { return }
        let groups = TokenUsageAntigravityQuotaParser.parse(data, capturedAt: now())
        guard !groups.isEmpty, !shouldCancel() else { return }
        store.replaceCompleteGroups(for: .antigravity, with: groups)
    }
}
