import Darwin
import Foundation

/// Watches the directory the status line adapter writes into and captures the
/// moment it changes.
///
/// The adapter writes a Claude limit reading on every status line render, but
/// the collector's periodic pass is deliberately slow — it exists to re-scan
/// Codex session tails and Antigravity databases, work worth doing rarely.
/// Leaving this reading on that clock meant a number harvested seconds ago
/// reached the surface up to half an hour later, which defeats the point of
/// harvesting it at all.
///
/// This is a file-system event source rather than a timer, so it costs nothing
/// while nothing is written, and it reads one small file when something is.
/// The same mechanism already carries queued usage events; this is the limits
/// counterpart.
final class TokenUsageLimitInboxMonitor: @unchecked Sendable {
    /// Posted after a capture actually stored something new, so surfaces can
    /// re-read without polling the snapshot file.
    static let limitsDidChangeNotification = Notification.Name("app.spill.token-usage-limits.did-change")

    private let directoryURL: URL
    private let capture: (TokenUsageLimitSnapshotStore) -> Bool
    private let snapshotStore: TokenUsageLimitSnapshotStore
    private let notificationCenter: NotificationCenter
    private let queue = DispatchQueue(label: "app.spill.token-usage-limit-inbox-monitor")
    private let lock = NSLock()
    private var source: DispatchSourceFileSystemObject?
    private var isCapturing = false
    private var isStopped = true

    init(
        directoryURL: URL = TokenUsageLimitInboxMonitor.defaultDirectoryURL(),
        snapshotStore: TokenUsageLimitSnapshotStore = TokenUsageLimitSnapshotStore(),
        notificationCenter: NotificationCenter = .default,
        capture: @escaping (TokenUsageLimitSnapshotStore) -> Bool = { store in
            TokenUsageClaudeStatuslineCapture().captureLatestSnapshots(into: store)
        }
    ) {
        self.directoryURL = directoryURL
        self.snapshotStore = snapshotStore
        self.notificationCenter = notificationCenter
        self.capture = capture
    }

    deinit {
        stop()
    }

    static func defaultDirectoryURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("limit-inbox", isDirectory: true)
    }

    func start() {
        lock.withLock {
            guard source == nil else {
                return
            }
            isStopped = false

            // The adapter creates this directory on its first write; watching
            // it has to work from a cold install, so it is created here too.
            try? FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let descriptor = Darwin.open(directoryURL.path, O_EVTONLY)
            guard descriptor >= 0 else {
                isStopped = true
                return
            }

            let nextSource = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .extend, .attrib, .rename, .delete],
                queue: queue
            )
            nextSource.setEventHandler { [weak self] in
                self?.requestCapture()
            }
            nextSource.setCancelHandler {
                Darwin.close(descriptor)
            }
            source = nextSource
            nextSource.resume()
        }

        // A reading may already be waiting from before this process started.
        requestCapture()
    }

    func stop() {
        lock.withLock {
            guard let source else {
                isStopped = true
                return
            }
            isStopped = true
            self.source = nil
            source.cancel()
        }
    }

    private func requestCapture() {
        guard lock.withLock({ !isStopped }) else {
            return
        }
        queue.async { [weak self] in
            self?.captureIfNeeded()
        }
    }

    private func captureIfNeeded() {
        let shouldCapture = lock.withLock {
            guard !isStopped, !isCapturing else {
                return false
            }
            isCapturing = true
            return true
        }
        guard shouldCapture else {
            return
        }
        defer {
            lock.withLock { isCapturing = false }
        }

        // The capture stores nothing when the reading is not newer than what a
        // tool already has, so a burst of writes cannot churn the surfaces.
        guard capture(snapshotStore) else {
            return
        }
        notificationCenter.post(name: Self.limitsDidChangeNotification, object: nil)
    }
}
