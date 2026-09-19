import Foundation

/// Owns the single periodic status loop and coalesces manual and scheduled reads.
@MainActor
final class SystemStatusRefreshCoordinator {
    typealias Sleep = @MainActor (TimeInterval) async throws -> Void

    private let interval: @MainActor () -> TimeInterval?
    private let refresh: @MainActor () async -> Void
    private let sleep: Sleep
    private var loopTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(
        interval: @escaping @MainActor () -> TimeInterval?,
        refresh: @escaping @MainActor () async -> Void,
        sleep: @escaping Sleep = { try await Task.sleep(for: .seconds($0)) }
    ) {
        self.interval = interval
        self.refresh = refresh
        self.sleep = sleep
    }

    deinit {
        loopTask?.cancel()
        refreshTask?.cancel()
    }

    func restart(startsImmediately: Bool = true) {
        loopTask?.cancel()
        let sleep = sleep
        loopTask = Task { @MainActor [weak self] in
            if !startsImmediately {
                guard let delay = self?.interval() else { return }
                do { try await sleep(delay) } catch { return }
            }

            while !Task.isCancelled {
                guard self?.interval() != nil else { return }
                await self?.refreshNow()
                guard !Task.isCancelled, let delay = self?.interval() else { return }
                do { try await sleep(delay) } catch { return }
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func refreshNow() async {
        if let refreshTask {
            await refreshTask.value
            return
        }

        let refresh = refresh
        let task = Task { @MainActor in await refresh() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    static func interval(
        isPanelVisible: Bool,
        hasMenuBarItems: Bool,
        usesPerformanceEffect: Bool,
        preferredInterval: TimeInterval
    ) -> TimeInterval? {
        if isPanelVisible { return 3 }
        guard hasMenuBarItems || usesPerformanceEffect else { return nil }
        return preferredInterval.isFinite ? max(preferredInterval, 3) : 15
    }
}
