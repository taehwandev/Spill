import Foundation

/// Keeps synchronous local-file reads out of SwiftUI notification callbacks.
@MainActor
final class TokenUsageDashboardLimitStore: ObservableObject {
    @Published private(set) var snapshots: [TokenUsageLimitSnapshot] = []
    private let queue = DispatchQueue(label: "app.spill.token-dashboard.limits", qos: .utility)
    private let read: @Sendable () -> [TokenUsageLimitSnapshot]
    private var isReading = false
    private var needsRefresh = false

    init(read: @escaping @Sendable () -> [TokenUsageLimitSnapshot] = {
        TokenUsageLimitSnapshotStore().allSnapshots()
    }) {
        self.read = read
    }

    func refresh() {
        guard !isReading else {
            needsRefresh = true
            return
        }
        isReading = true
        let read = read
        queue.async { [weak self] in
            let next = read()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.snapshots != next {
                    self.snapshots = next
                }
                self.isReading = false
                if self.needsRefresh {
                    self.needsRefresh = false
                    self.refresh()
                }
            }
        }
    }
}
