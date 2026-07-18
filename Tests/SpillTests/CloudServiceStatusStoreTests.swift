import Foundation
import XCTest
@testable import Spill

@MainActor
final class CloudServiceStatusStoreTests: XCTestCase {
    func testRefreshUsesFreshCacheWithoutNetworkCall() async throws {
        let cacheURL = temporaryCacheURL()
        let cachedSnapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            items: [cachedItem(health: .operational)]
        )
        try writeCache(cachedSnapshot, to: cacheURL)
        let requestCounter = RequestCounter()
        let store = CloudServiceStatusStore(
            provider: CloudServiceStatusProvider { _ in
                await requestCounter.increment()
                return Data("[]".utf8)
            },
            cacheURL: cacheURL,
            cacheTTL: 15 * 60,
            now: { Date(timeIntervalSince1970: 1_100) }
        )

        store.refreshIfNeeded()
        try await waitForNonLoadingState(in: store)

        let requestCount = await requestCounter.currentValue()
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(store.snapshot, cachedSnapshot)
    }

    func testIssueCacheUsesShorterTTLWithoutNetworkCallBeforeExpiry() async throws {
        let cacheURL = temporaryCacheURL()
        let cachedSnapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            items: [cachedItem(health: .outage)]
        )
        try writeCache(cachedSnapshot, to: cacheURL)
        let requestCounter = RequestCounter()
        let store = CloudServiceStatusStore(
            provider: CloudServiceStatusProvider { _ in
                await requestCounter.increment()
                return Data("[]".utf8)
            },
            cacheURL: cacheURL,
            cacheTTL: 15 * 60,
            issueCacheTTL: 5 * 60,
            now: { Date(timeIntervalSince1970: 1_250) }
        )

        store.refreshIfNeeded()
        try await waitForNonLoadingState(in: store)

        let requestCount = await requestCounter.currentValue()
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(store.snapshot, cachedSnapshot)
    }

    func testIssueCacheRefreshesAfterShortTTL() async throws {
        let cacheURL = temporaryCacheURL()
        let cachedSnapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            items: [cachedItem(health: .outage)]
        )
        try writeCache(cachedSnapshot, to: cacheURL)
        let requestCounter = RequestCounter()
        let openAIStatusJSON = Self.operationalStatusPageJSON
        let claudeStatusJSON = Self.operationalClaudeStatusJSON
        let store = CloudServiceStatusStore(
            provider: CloudServiceStatusProvider { url in
                await requestCounter.increment()
                switch url {
                case CloudServiceStatusProvider.openAIStatusURL:
                    return Data(openAIStatusJSON.utf8)
                case CloudServiceStatusProvider.claudeStatusURL:
                    return Data(claudeStatusJSON.utf8)
                case CloudServiceStatusProvider.googleCloudIncidentsURL:
                    return Data("[]".utf8)
                default:
                    throw CloudServiceStatusError.invalidHTTPStatus(404)
                }
            },
            cacheURL: cacheURL,
            cacheTTL: 15 * 60,
            issueCacheTTL: 5 * 60,
            now: { Date(timeIntervalSince1970: 1_301) }
        )

        store.refreshIfNeeded()
        try await waitForLoadedState(in: store)

        let requestCount = await requestCounter.currentValue()
        XCTAssertEqual(requestCount, 3)
        XCTAssertNotEqual(store.snapshot, cachedSnapshot)
    }

    func testForceRefreshBypassesFreshCache() async throws {
        let cacheURL = temporaryCacheURL()
        let cachedSnapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            items: [cachedItem(health: .operational)]
        )
        try writeCache(cachedSnapshot, to: cacheURL)
        let requestCounter = RequestCounter()
        let openAIStatusJSON = Self.operationalStatusPageJSON
        let claudeStatusJSON = Self.operationalClaudeStatusJSON
        let store = CloudServiceStatusStore(
            provider: CloudServiceStatusProvider { url in
                await requestCounter.increment()
                switch url {
                case CloudServiceStatusProvider.openAIStatusURL:
                    return Data(openAIStatusJSON.utf8)
                case CloudServiceStatusProvider.claudeStatusURL:
                    return Data(claudeStatusJSON.utf8)
                case CloudServiceStatusProvider.googleCloudIncidentsURL:
                    return Data("[]".utf8)
                default:
                    throw CloudServiceStatusError.invalidHTTPStatus(404)
                }
            },
            cacheURL: cacheURL,
            cacheTTL: 15 * 60,
            now: { Date(timeIntervalSince1970: 1_100) }
        )

        store.refreshIfNeeded(force: true)
        try await waitForLoadedState(in: store)

        let requestCount = await requestCounter.currentValue()
        XCTAssertEqual(requestCount, 3)
        XCTAssertNotEqual(store.snapshot, cachedSnapshot)
    }

    func testExpiredCacheRefreshesFromNetwork() async throws {
        let cacheURL = temporaryCacheURL()
        let cachedSnapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            items: [cachedItem(health: .operational)]
        )
        try writeCache(cachedSnapshot, to: cacheURL)
        let requestCounter = RequestCounter()
        let openAIStatusJSON = Self.operationalStatusPageJSON
        let claudeStatusJSON = Self.operationalClaudeStatusJSON
        let store = CloudServiceStatusStore(
            provider: CloudServiceStatusProvider { url in
                await requestCounter.increment()
                switch url {
                case CloudServiceStatusProvider.openAIStatusURL:
                    return Data(openAIStatusJSON.utf8)
                case CloudServiceStatusProvider.claudeStatusURL:
                    return Data(claudeStatusJSON.utf8)
                case CloudServiceStatusProvider.googleCloudIncidentsURL:
                    return Data("[]".utf8)
                default:
                    throw CloudServiceStatusError.invalidHTTPStatus(404)
                }
            },
            cacheURL: cacheURL,
            cacheTTL: 15 * 60,
            now: { Date(timeIntervalSince1970: 2_000) }
        )

        store.refreshIfNeeded()
        try await waitForLoadedState(in: store)

        let requestCount = await requestCounter.currentValue()
        XCTAssertEqual(requestCount, 3)
        XCTAssertNotEqual(store.snapshot, cachedSnapshot)
    }

    func testRemoteRefreshRequestsNetworkOwnerWithoutCallingProvider() async {
        let cacheURL = temporaryCacheURL()
        let requestCounter = RequestCounter()
        var delegatedForces = [Bool]()
        let store = CloudServiceStatusStore(
            provider: CloudServiceStatusProvider { _ in
                await requestCounter.increment()
                return Data("[]".utf8)
            },
            cacheURL: cacheURL,
            remoteRefreshRequest: { force in
                delegatedForces.append(force)
            }
        )

        store.refreshIfNeeded(force: true)

        XCTAssertEqual(delegatedForces, [true])
        XCTAssertTrue(store.isLoading)
        let requestCount = await requestCounter.currentValue()
        XCTAssertEqual(requestCount, 0)
        store.cancelRefresh()
    }

    func testRemoteRefreshUsesFreshSharedCacheWithoutDelegating() throws {
        let cacheURL = temporaryCacheURL()
        let now = Date(timeIntervalSince1970: 2_000)
        let cachedSnapshot = CloudServiceStatusSnapshot(
            fetchedAt: now.addingTimeInterval(-30),
            items: [cachedItem(health: .operational)]
        )
        try writeCache(cachedSnapshot, to: cacheURL)
        var delegatedForces = [Bool]()
        let store = CloudServiceStatusStore(
            cacheURL: cacheURL,
            now: { now },
            remoteRefreshRequest: { force in
                delegatedForces.append(force)
            }
        )

        store.refreshIfNeeded()

        XCTAssertTrue(delegatedForces.isEmpty)
        XCTAssertEqual(store.state, .loaded(cachedSnapshot))
    }

    func testRemoteRefreshReloadsNewerSharedCacheSnapshot() throws {
        let cacheURL = temporaryCacheURL()
        let initialSnapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            items: [cachedItem(health: .operational)]
        )
        let updatedSnapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 2_000),
            items: [cachedItem(health: .degraded)]
        )
        try writeCache(initialSnapshot, to: cacheURL)
        let store = CloudServiceStatusStore(
            cacheURL: cacheURL,
            remoteRefreshRequest: { _ in }
        )

        store.refreshIfNeeded(force: true)
        try writeCache(updatedSnapshot, to: cacheURL)

        XCTAssertTrue(store.reloadFromCacheIfNewer())
        XCTAssertEqual(store.state, .loaded(updatedSnapshot))
        XCTAssertFalse(store.isLoading)
    }

    func testNetworkOwnerPublishesCacheUpdateAfterSuccessfulRefresh() async throws {
        let cacheURL = temporaryCacheURL()
        let openAIStatusJSON = Self.operationalStatusPageJSON
        let claudeStatusJSON = Self.operationalClaudeStatusJSON
        var cacheUpdateCount = 0
        let store = CloudServiceStatusStore(
            provider: CloudServiceStatusProvider { url in
                switch url {
                case CloudServiceStatusProvider.openAIStatusURL:
                    return Data(openAIStatusJSON.utf8)
                case CloudServiceStatusProvider.claudeStatusURL:
                    return Data(claudeStatusJSON.utf8)
                case CloudServiceStatusProvider.googleCloudIncidentsURL:
                    return Data("[]".utf8)
                default:
                    throw CloudServiceStatusError.invalidHTTPStatus(404)
                }
            },
            cacheURL: cacheURL,
            cacheDidUpdate: {
                cacheUpdateCount += 1
            }
        )

        store.refreshIfNeeded(force: true)
        try await waitForLoadedState(in: store)

        XCTAssertEqual(cacheUpdateCount, 1)
        let cachedData = try Data(contentsOf: cacheURL)
        let cachedSnapshot = try JSONDecoder().decode(CloudServiceStatusSnapshot.self, from: cachedData)
        XCTAssertEqual(cachedSnapshot, store.snapshot)
    }

    private func waitForLoadedState(in store: CloudServiceStatusStore) async throws {
        for _ in 0..<50 {
            if case .loaded = store.state {
                return
            }

            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTFail("Timed out waiting for loaded service status state.")
    }

    private func waitForNonLoadingState(in store: CloudServiceStatusStore) async throws {
        for _ in 0..<50 {
            if !store.isLoading {
                return
            }

            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTFail("Timed out waiting for service status state.")
    }

    private func temporaryCacheURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("cache.json")
    }

    private func cachedItem(health: CloudServiceHealth) -> CloudServiceStatusItem {
        CloudServiceStatusItem(
            kind: .codex,
            health: health,
            detail: "Cached",
            source: "Test"
        )
    }

    private func writeCache(_ snapshot: CloudServiceStatusSnapshot, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url)
    }

    private static let operationalStatusPageJSON = """
    {
      "status": { "description": "All Systems Operational", "indicator": "none" },
      "components": [
        { "name": "Responses", "status": "operational" },
        { "name": "CLI", "status": "operational" },
        { "name": "Codex API", "status": "operational" },
        { "name": "VS Code extension", "status": "operational" }
      ]
    }
    """

    private static let operationalClaudeStatusJSON = """
    {
      "status": { "description": "All Systems Operational", "indicator": "none" },
      "components": [
        { "name": "Claude Code", "status": "operational" },
        { "name": "Claude API", "status": "operational" }
      ]
    }
    """
}

private actor RequestCounter {
    private var count = 0

    func currentValue() -> Int {
        count
    }

    func increment() {
        count += 1
    }
}
