import Foundation
import SwiftUI

@MainActor
final class CloudServiceStatusStore: ObservableObject {
    @Published private(set) var state: CloudServiceStatusState

    private let provider: CloudServiceStatusProvider
    private let cacheURL: URL
    private let cacheTTL: TimeInterval
    private let issueCacheTTL: TimeInterval
    private let now: () -> Date
    private var refreshTask: Task<Void, Never>?

    init(
        provider: CloudServiceStatusProvider = CloudServiceStatusProvider(),
        cacheURL: URL = CloudServiceStatusStore.defaultCacheURL(),
        cacheTTL: TimeInterval = CloudServiceStatusProvider.defaultCacheTTL,
        issueCacheTTL: TimeInterval = CloudServiceStatusProvider.issueCacheTTL,
        now: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.cacheURL = cacheURL
        self.cacheTTL = cacheTTL
        self.issueCacheTTL = issueCacheTTL
        self.now = now
        state = .idle(snapshot: Self.readCache(from: cacheURL))
    }

    deinit {
        refreshTask?.cancel()
    }

    var snapshot: CloudServiceStatusSnapshot? {
        state.snapshot
    }

    var isLoading: Bool {
        if case .loading = state {
            return true
        }

        return false
    }

    func refreshIfNeeded(force: Bool = false) {
        guard !isLoading else {
            return
        }

        let cachedSnapshot = state.snapshot
        if !force,
           let cachedSnapshot,
           cachedSnapshot.isFresh(now: now(), healthyTTL: cacheTTL, issueTTL: issueCacheTTL) {
            state = .loaded(cachedSnapshot)
            return
        }

        state = .loading(snapshot: cachedSnapshot)
        refreshTask?.cancel()
        let provider = provider
        let cacheURL = cacheURL
        let now = now

        refreshTask = Task { @MainActor [weak self] in
            let snapshot = await provider.snapshot(now: now())
            guard !Task.isCancelled else {
                return
            }

            Self.writeCache(snapshot, to: cacheURL)
            self?.state = .loaded(snapshot)
        }
    }

    private static func defaultCacheURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("Spill", isDirectory: true)
            .appendingPathComponent("cloud-service-status-cache.json")
    }

    private static func readCache(from url: URL) -> CloudServiceStatusSnapshot? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(CloudServiceStatusSnapshot.self, from: data)
    }

    private static func writeCache(_ snapshot: CloudServiceStatusSnapshot, to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Cache failure should not create any extra network side effect.
            return
        }
    }
}

enum CloudServiceStatusState: Equatable {
    case idle(snapshot: CloudServiceStatusSnapshot?)
    case loading(snapshot: CloudServiceStatusSnapshot?)
    case loaded(CloudServiceStatusSnapshot)

    var snapshot: CloudServiceStatusSnapshot? {
        switch self {
        case .idle(let snapshot), .loading(let snapshot):
            return snapshot
        case .loaded(let snapshot):
            return snapshot
        }
    }
}
