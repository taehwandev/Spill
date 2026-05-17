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
    @Published private(set) var scanMessage: String = "Not scanned yet."
    @Published private(set) var lastScannedAt: Date?
    @Published private(set) var isScanning = false

    private let applicationProvider = MenuBarApplicationProvider()
    private let imageProvider = MenuBarItemImageProvider()
    private let reader = AXElementReader()
    private var elementsByID: [MenuBarItemSnapshot.ID: MenuBarElementReference] = [:]
    private var imageDataCache: [String: Data] = [:]
    private var missingImageKeys = Set<String>()
    private var pendingRefresh = false
    private var pendingRefreshReason = MenuBarScanRefreshReason.manual
    private var refreshTask: Task<Void, Never>?
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
        refreshTask = nil
        isScanning = false
        pendingRefresh = false
        pendingRefreshReason = .manual
        items = []
        elementsByID = [:]
        lastScannedAt = nil
        scanMessage = "Accessibility is not trusted for this Spill build. Recheck after granting it, or remove and re-add this app in Privacy settings."
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
                scanMessage = "Refresh queued while the current scan finishes."
            }
            return false
        }

        let applications = applicationProvider.candidates()
        let notchGeometry = MenuBarNotchGeometry(screen: NSScreen.main)

        isScanning = true
        scanMessage = lastScannedAt == nil ? "Scanning menu bar items..." : "Refreshing menu bar items..."

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
            scanMessage = "The selected menu bar item is no longer available."
            requestRefreshAfterFailedPress()
            return false
        }

        let result = reader.performPress(on: reference.element)
        if result == .success {
            scanMessage = "Performed primary action for the selected menu bar item."
            return true
        }

        scanMessage = "Could not press the selected menu bar item. AX returned \(result.rawValue)."
        requestRefreshAfterFailedPress()
        return false
    }

    private func completeRefresh(_ result: MenuBarScanResult) {
        guard !Task.isCancelled else {
            return
        }

        let enrichedItems = result.items.map { snapshot in
            guard snapshot.isNotchCandidate else {
                return snapshot
            }

            return snapshot.withImageData(cachedImageData(for: snapshot))
        }
        let hadPreviousScan = lastScannedAt != nil
        let didChangeItems = enrichedItems != items
        if didChangeItems {
            items = enrichedItems
        }
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
        let suffix = hadPreviousScan && !didChangeItems ? " Cached result unchanged." : ""

        if items.isEmpty {
            return "No menu bar items found. Scanned \(stats.candidateCount) apps, \(stats.menuBarRootCount) menu bar roots (\(stats.extrasRootCount) extras, \(stats.fallbackRootCount) fallback), \(stats.representableElementCount) candidate elements.\(suffix)"
        } else if notchCount == 0 {
            return "Detected \(items.count) menu bar item(s). Scanned \(stats.menuBarRootCount) menu bar roots; no notch overlap candidate found.\(suffix)"
        } else {
            return "Detected \(items.count) menu bar item(s), \(notchCount) near the notch estimate.\(suffix)"
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

    private func cachedImageData(for item: MenuBarItemSnapshot) -> Data? {
        let key = item.bundleIdentifier ?? "pid:\(item.processIdentifier)"

        if let cached = imageDataCache[key] {
            return cached
        }

        if missingImageKeys.contains(key) {
            return nil
        }

        guard let imageData = imageProvider.imageData(
            bundleIdentifier: item.bundleIdentifier,
            processIdentifier: item.processIdentifier
        ) else {
            missingImageKeys.insert(key)
            return nil
        }

        imageDataCache[key] = imageData
        return imageData
    }
}
