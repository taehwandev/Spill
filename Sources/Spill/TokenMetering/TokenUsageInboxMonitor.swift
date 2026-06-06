import Darwin
import Foundation

final class TokenUsageInboxMonitor: @unchecked Sendable {
    private let store: TokenUsageStore
    private let queue = DispatchQueue(label: "app.spill.token-usage-inbox-monitor")
    private let lock = NSLock()
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1

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
            nextSource.setEventHandler { [weak store] in
                store?.importQueuedEventsWithoutLoading()
            }
            nextSource.setCancelHandler {
                Darwin.close(descriptor)
            }

            fileDescriptor = descriptor
            source = nextSource
            nextSource.resume()
        }

        store.importQueuedEventsWithoutLoading()
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
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
