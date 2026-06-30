import AppKit
import ApplicationServices
import Foundation

enum MenuBarScanRefreshReason: Sendable {
    case applicationActivation
    case manual
    case panelOpen
    case screenChange
    case staleReference
    case timer
    case workspaceChange
}

struct MenuBarScanRefreshPolicy: Sendable {
    let minimumRefreshInterval: TimeInterval

    init(minimumRefreshInterval: TimeInterval = 15) {
        self.minimumRefreshInterval = minimumRefreshInterval
    }

    func shouldRefresh(
        lastScannedAt: Date?,
        now: Date,
        force: Bool,
        minimumRefreshInterval override: TimeInterval? = nil
    ) -> Bool {
        if force {
            return true
        }

        guard let lastScannedAt else {
            return true
        }

        return now.timeIntervalSince(lastScannedAt) >= (override ?? minimumRefreshInterval)
    }
}

@MainActor
final class AXMenuBarItemScanner: ObservableObject {
    @Published private(set) var items: [MenuBarItemSnapshot] = []
    @Published private(set) var scanMessage: String = AppL10n.text(.notScannedYet)
    @Published private(set) var lastScannedAt: Date?
    @Published private(set) var isScanning = false

    private let applicationProvider = MenuBarApplicationProvider()
    private let reader = AXElementReader()
    private var elementsByID: [MenuBarItemSnapshot.ID: MenuBarElementReference] = [:]
    private var imageDataCache: [String: Data] = [:]
    private var missingImageKeys = Set<String>()
    private var pendingRefresh = false
    private var pendingRefreshReason = MenuBarScanRefreshReason.manual
    private var refreshTask: Task<Void, Never>?
    private var iconRefreshTask: Task<Void, Never>?
    private var iconRefreshGeneration = 0
    private let refreshPolicy: MenuBarScanRefreshPolicy
    private let dateProvider: () -> Date

    init(
        refreshPolicy: MenuBarScanRefreshPolicy = MenuBarScanRefreshPolicy(),
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.refreshPolicy = refreshPolicy
        self.dateProvider = dateProvider
    }

    var visibleItems: [MenuBarItemSnapshot] {
        notchCandidates
    }

    var notchCandidates: [MenuBarItemSnapshot] {
        items.filter(\.isNotchCandidate)
    }

    func clearForMissingPermission() {
        refreshTask?.cancel()
        iconRefreshTask?.cancel()
        refreshTask = nil
        iconRefreshTask = nil
        isScanning = false
        pendingRefresh = false
        pendingRefreshReason = .manual
        items = []
        elementsByID = [:]
        imageDataCache.removeAll()
        missingImageKeys.removeAll()
        lastScannedAt = nil
        scanMessage = AppL10n.text(.accessibilityNotTrusted)
    }

    @discardableResult
    func refresh(
        force: Bool = true,
        reason: MenuBarScanRefreshReason = .manual,
        minimumRefreshInterval: TimeInterval? = nil
    ) -> Bool {
        guard AccessibilityPermission.isTrusted else {
            clearForMissingPermission()
            return false
        }

        let now = dateProvider()
        guard refreshPolicy.shouldRefresh(
            lastScannedAt: lastScannedAt,
            now: now,
            force: force,
            minimumRefreshInterval: minimumRefreshInterval
        ) else {
            return false
        }

        guard !isScanning else {
            if force {
                pendingRefresh = true
                pendingRefreshReason = reason
                scanMessage = AppL10n.text(.refreshQueued)
            }
            return false
        }

        let applications = applicationProvider.candidates()
        let notchGeometry = MenuBarNotchGeometry(screen: NSScreen.main)

        isScanning = true
        scanMessage = lastScannedAt == nil
            ? AppL10n.text(.scanningMenuBarItems)
            : AppL10n.text(.refreshingMenuBarItems)

        let workerTask = Task.detached(priority: .utility) {
            AXMenuBarScanWorker(notchGeometry: notchGeometry).scan(applications: applications)
        }

        refreshTask = Task { [weak self] in
            let result = await workerTask.value
            self?.completeRefresh(result)
        }
        return true
    }

    @discardableResult
    func refreshIfStale(
        reason: MenuBarScanRefreshReason,
        minimumRefreshInterval: TimeInterval? = nil
    ) -> Bool {
        refresh(force: false, reason: reason, minimumRefreshInterval: minimumRefreshInterval)
    }

    @discardableResult
    func pressItem(withID id: MenuBarItemSnapshot.ID) -> Bool {
        guard let reference = elementsByID[id] else {
            scanMessage = AppL10n.text(.selectedItemUnavailable)
            requestRefreshAfterFailedPress()
            return false
        }

        let result = reader.performPress(on: reference.element)
        if result == .success {
            scanMessage = AppL10n.text(.performedPrimaryAction)
            return true
        }

        scanMessage = AppL10n.pressFailed(result: Int(result.rawValue))
        requestRefreshAfterFailedPress()
        return false
    }

    private func completeRefresh(_ result: MenuBarScanResult) {
        guard !Task.isCancelled else {
            return
        }

        let enrichedItems = result.items.map { snapshot in
            guard snapshot.isNotchCandidate,
                  let imageData = cachedImageDataIfAvailable(for: snapshot)
            else {
                return snapshot
            }

            return snapshot.withImageData(imageData)
        }
        let iconGeneration = nextIconRefreshGeneration()
        let hadPreviousScan = lastScannedAt != nil
        let didChangeItems = enrichedItems != items
        if didChangeItems {
            items = enrichedItems
        }
        pruneStaleProcessIconCacheEntries(for: enrichedItems)
        elementsByID = result.elementsByID
        lastScannedAt = dateProvider()
        isScanning = false
        scanMessage = message(
            for: result.stats,
            items: enrichedItems,
            hadPreviousScan: hadPreviousScan,
            didChangeItems: didChangeItems
        )
        refreshTask = nil
        refreshMissingIcons(for: enrichedItems, generation: iconGeneration)

        if pendingRefresh {
            let queuedReason = pendingRefreshReason
            pendingRefresh = false
            pendingRefreshReason = .manual
            refresh(force: true, reason: queuedReason)
        }
    }

    private func message(
        for stats: MenuBarScanStats,
        items: [MenuBarItemSnapshot],
        hadPreviousScan: Bool,
        didChangeItems: Bool
    ) -> String {
        let notchCount = items.filter(\.isNotchCandidate).count
        let suffix = hadPreviousScan && !didChangeItems ? AppL10n.text(.cachedResultUnchanged) : ""

        if items.isEmpty {
            return AppL10n.noMenuBarItemsFound(
                candidateCount: stats.candidateCount,
                menuBarRootCount: stats.menuBarRootCount,
                extrasRootCount: stats.extrasRootCount,
                fallbackRootCount: stats.fallbackRootCount,
                representableElementCount: stats.representableElementCount,
                suffix: suffix
            )
        } else if notchCount == 0 {
            return AppL10n.detectedNoNotch(
                itemCount: items.count,
                menuBarRootCount: stats.menuBarRootCount,
                suffix: suffix
            )
        } else {
            return AppL10n.detectedNearNotch(
                itemCount: items.count,
                notchCount: notchCount,
                suffix: suffix
            )
        }
    }

    private func requestRefreshAfterFailedPress() {
        guard AccessibilityPermission.isTrusted else {
            return
        }

        Task { @MainActor [weak self] in
            self?.refresh(force: true, reason: .staleReference)
        }
    }

    private func cachedImageDataIfAvailable(for item: MenuBarItemSnapshot) -> Data? {
        imageDataCache[iconCacheKey(for: item)]
    }

    private func iconCacheKey(for item: MenuBarItemSnapshot) -> String {
        item.bundleIdentifier ?? "pid:\(item.processIdentifier)"
    }

    private func pruneStaleProcessIconCacheEntries(for items: [MenuBarItemSnapshot]) {
        let currentProcessKeys = Set(items.map { "pid:\($0.processIdentifier)" })

        imageDataCache = imageDataCache.filter { key, _ in
            !key.hasPrefix("pid:") || currentProcessKeys.contains(key)
        }
        missingImageKeys = missingImageKeys.filter { key in
            !key.hasPrefix("pid:") || currentProcessKeys.contains(key)
        }
    }

    private func nextIconRefreshGeneration() -> Int {
        iconRefreshTask?.cancel()
        iconRefreshGeneration += 1
        return iconRefreshGeneration
    }

    private func refreshMissingIcons(for items: [MenuBarItemSnapshot], generation: Int) {
        let requests = items.compactMap { item -> MenuBarIconLoadRequest? in
            guard item.isNotchCandidate, item.imageData == nil else {
                return nil
            }

            let key = iconCacheKey(for: item)
            guard !missingImageKeys.contains(key) else {
                return nil
            }

            return MenuBarIconLoadRequest(
                id: item.id,
                key: key,
                bundleIdentifier: item.bundleIdentifier,
                processIdentifier: item.processIdentifier
            )
        }

        guard !requests.isEmpty else {
            return
        }

        iconRefreshTask = Task.detached(priority: .utility) {
            let provider = MenuBarItemImageProvider()
            var loaded = [String: (key: String, data: Data)]()
            var missingKeys = Set<String>()

            for request in requests {
                guard !Task.isCancelled else {
                    return
                }

                if let imageData = provider.imageData(
                    bundleIdentifier: request.bundleIdentifier,
                    processIdentifier: request.processIdentifier
                ) {
                    MenuBarIconImageCache.shared.prepareImage(for: imageData)
                    loaded[request.id] = (request.key, imageData)
                } else {
                    missingKeys.insert(request.key)
                }
            }

            await MainActor.run { [weak self] in
                self?.applyLoadedIcons(
                    loaded,
                    missingKeys: missingKeys,
                    generation: generation
                )
            }
        }
    }

    private func applyLoadedIcons(
        _ loaded: [String: (key: String, data: Data)],
        missingKeys: Set<String>,
        generation: Int
    ) {
        guard generation == iconRefreshGeneration else {
            return
        }

        missingImageKeys.formUnion(missingKeys)
        guard !loaded.isEmpty else {
            return
        }

        for value in loaded.values {
            imageDataCache[value.key] = value.data
        }

        let updatedItems = items.map { item in
            guard item.isNotchCandidate,
                  item.imageData == nil,
                  let loadedIcon = loaded[item.id]
            else {
                return item
            }

            return item.withImageData(loadedIcon.data)
        }

        if updatedItems != items {
            items = updatedItems
        }
    }
}

private struct MenuBarIconLoadRequest: Sendable {
    let id: String
    let key: String
    let bundleIdentifier: String?
    let processIdentifier: pid_t
}
