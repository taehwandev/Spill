import Darwin
import Foundation

final class TokenUsageInboxMonitor: @unchecked Sendable {
    private let store: TokenUsageStore
    private let queue = DispatchQueue(label: "app.spill.token-usage-inbox-monitor")
    private let lock = NSLock()
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var isDraining = false

    init(store: TokenUsageStore) {
        self.store = store
    }

    deinit {
        stop()
    }

    func start() {
        lock.withLock {
            guard source == nil else {
                return
            }

            let inboxURL = store.eventsInboxURL ?? TokenUsageStore.defaultInboxURL()
            try? FileManager.default.createDirectory(
                at: inboxURL,
                withIntermediateDirectories: true
            )

            let descriptor = Darwin.open(inboxURL.path, O_EVTONLY)
            guard descriptor >= 0 else {
                return
            }

            let nextSource = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .extend, .attrib, .rename, .delete],
                queue: queue
            )
            nextSource.setEventHandler { [weak self] in
                self?.requestDrain()
            }
            nextSource.setCancelHandler {
                Darwin.close(descriptor)
            }

            fileDescriptor = descriptor
            source = nextSource
            nextSource.resume()
        }

        requestDrain()
    }

    func stop() {
        lock.withLock {
            guard let source else {
                return
            }

            self.source = nil
            fileDescriptor = -1
            source.cancel()
        }
    }

    private func requestDrain() {
        queue.async { [weak self] in
            self?.drainIfNeeded()
        }
    }

    private func drainIfNeeded() {
        let shouldDrain = lock.withLock {
            guard !isDraining else {
                return false
            }
            isDraining = true
            return true
        }
        guard shouldDrain else {
            return
        }

        defer {
            lock.withLock {
                isDraining = false
            }
        }

        _ = autoreleasepool {
            store.drainQueuedEventsWithoutLoading(
                maximumInboxEventCount: TokenUsageStore.defaultInboxImportBatchLimit,
                scheduleFollowUpDrain: { [weak self] in
                    guard let self else { return }
                    queue.asyncAfter(deadline: .now() + .milliseconds(25)) { [weak self] in
                        self?.requestDrain()
                    }
                }
            )
        }
    }
}
