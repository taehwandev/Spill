import AppKit
import ApplicationServices
import Foundation

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
    private var refreshTask: Task<Void, Never>?

    var visibleItems: [MenuBarItemSnapshot] {
        if notchCandidates.isEmpty {
            return items
        }

        return notchCandidates
    }

    var notchCandidates: [MenuBarItemSnapshot] {
        items.filter(\.isNotchCandidate)
    }

    func clearForMissingPermission() {
        refreshTask?.cancel()
        refreshTask = nil
        isScanning = false
        pendingRefresh = false
        items = []
        elementsByID = [:]
        lastScannedAt = nil
        scanMessage = "Accessibility is not trusted for this Spill build. Recheck after granting it, or remove and re-add this app in Privacy settings."
    }

    func refresh() {
        guard AccessibilityPermission.isTrusted else {
            clearForMissingPermission()
            return
        }

        let applications = applicationProvider.candidates()
        let notchGeometry = MenuBarNotchGeometry(screen: NSScreen.main)

        guard !isScanning else {
            pendingRefresh = true
            scanMessage = "Refresh queued while the current scan finishes."
            return
        }

        isScanning = true
        scanMessage = lastScannedAt == nil ? "Scanning menu bar items..." : "Refreshing menu bar items..."

        let workerTask = Task.detached(priority: .utility) {
            AXMenuBarScanWorker(notchGeometry: notchGeometry).scan(applications: applications)
        }

        refreshTask = Task { [weak self] in
            let result = await workerTask.value
            self?.completeRefresh(result)
        }
    }

    @discardableResult
    func pressItem(withID id: MenuBarItemSnapshot.ID) -> Bool {
        guard let reference = elementsByID[id] else {
            scanMessage = "The selected menu bar item is no longer available."
            return false
        }

        let result = reader.performPress(on: reference.element)
        if result == .success {
            scanMessage = "Performed primary action for the selected menu bar item."
            return true
        }

        scanMessage = "Could not press the selected menu bar item. AX returned \(result.rawValue)."
        return false
    }

    private func completeRefresh(_ result: MenuBarScanResult) {
        guard !Task.isCancelled else {
            return
        }

        let enrichedItems = result.items.map { snapshot in
            snapshot.withImageData(cachedImageData(for: snapshot))
        }
        items = enrichedItems
        elementsByID = result.elementsByID
        lastScannedAt = Date()
        isScanning = false
        scanMessage = message(for: result.stats, items: enrichedItems)
        refreshTask = nil

        if pendingRefresh {
            pendingRefresh = false
            refresh()
        }
    }

    private func message(for stats: MenuBarScanStats, items: [MenuBarItemSnapshot]) -> String {
        let notchCount = items.filter(\.isNotchCandidate).count

        if items.isEmpty {
            return "No menu bar items found. Scanned \(stats.candidateCount) apps, \(stats.menuBarRootCount) menu bar roots (\(stats.extrasRootCount) extras, \(stats.fallbackRootCount) fallback), \(stats.representableElementCount) candidate elements."
        } else if notchCount == 0 {
            return "Detected \(items.count) menu bar item(s). Scanned \(stats.menuBarRootCount) menu bar roots; no notch overlap candidate found."
        } else {
            return "Detected \(items.count) menu bar item(s), \(notchCount) near the notch estimate."
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
