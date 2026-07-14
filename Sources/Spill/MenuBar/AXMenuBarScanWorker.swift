import ApplicationServices
import CoreGraphics
import Foundation

struct MenuBarElementReference: @unchecked Sendable {
    let element: AXUIElement
}

struct MenuBarScanResult: @unchecked Sendable {
    let items: [MenuBarItemSnapshot]
    let elementsByID: [MenuBarItemSnapshot.ID: MenuBarElementReference]
    let stats: MenuBarScanStats
}

struct MenuBarScanStats: Sendable {
    var candidateCount = 0
    var menuBarRootCount = 0
    var extrasRootCount = 0
    var fallbackRootCount = 0
    var representableElementCount = 0
}

struct AXMenuBarScanWorker: @unchecked Sendable {
    private let maximumTraversalDepth = 5
    private let reader = AXElementReader()
    private let notchGeometry: MenuBarNotchGeometry
    private let snapshotBuilder: MenuBarItemSnapshotBuilder

    init(notchGeometry: MenuBarNotchGeometry) {
        self.notchGeometry = notchGeometry
        snapshotBuilder = MenuBarItemSnapshotBuilder(notchGeometry: notchGeometry)
    }

    func scan(applications: [MenuBarApplicationCandidate]) -> MenuBarScanResult {
        var discovered: [MenuBarItemSnapshot] = []
        var elementIndex: [MenuBarItemSnapshot.ID: MenuBarElementReference] = [:]
        var stats = MenuBarScanStats()
        stats.candidateCount = applications.count

        for application in applications {
            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            let roots = menuBars(for: appElement, application: application)
            stats.menuBarRootCount += roots.count
            stats.extrasRootCount += roots.filter(\.isExtrasMenuBar).count
            stats.fallbackRootCount += roots.filter { !$0.isExtrasMenuBar }.count

            for root in roots {
                collectItems(
                    from: root.element,
                    ownerName: application.ownerName,
                    bundleIdentifier: application.bundleIdentifier,
                    processIdentifier: application.processIdentifier,
                    depth: 0,
                    snapshots: &discovered,
                    elements: &elementIndex,
                    stats: &stats
                )
            }
        }

        let uniqueItems = uniqued(discovered)
            .sorted { first, second in
                if first.frame.minY == second.frame.minY {
                    return first.frame.minX < second.frame.minX
                }

                return first.frame.minY > second.frame.minY
            }
        let uniqueIDs = Set(uniqueItems.map(\.id))

        return MenuBarScanResult(
            items: uniqueItems,
            elementsByID: elementIndex.filter { uniqueIDs.contains($0.key) },
            stats: stats
        )
    }
}

private extension AXMenuBarScanWorker {
    private func menuBars(
        for applicationElement: AXUIElement,
        application: MenuBarApplicationCandidate
    ) -> [MenuBarRoot] {
        var bars: [MenuBarRoot] = []

        if let extrasMenuBar = reader.elementAttribute(applicationElement, AXAttributeName.extrasMenuBar) {
            bars.append(MenuBarRoot(element: extrasMenuBar, isExtrasMenuBar: true))
        }

        if bars.isEmpty,
           application.usesMenuBarFallback,
           let menuBar = reader.elementAttribute(applicationElement, AXAttributeName.menuBar)
        {
            bars.append(MenuBarRoot(element: menuBar, isExtrasMenuBar: false))
        }

        return bars
    }

    private func collectItems(
        from element: AXUIElement,
        ownerName: String,
        bundleIdentifier: String?,
        processIdentifier: pid_t,
        depth: Int,
        snapshots: inout [MenuBarItemSnapshot],
        elements: inout [MenuBarItemSnapshot.ID: MenuBarElementReference],
        stats: inout MenuBarScanStats
    ) {
        guard depth <= maximumTraversalDepth else {
            return
        }

        let role = reader.stringAttribute(element, AXAttributeName.role) ?? ""
        let frame = reader.frame(of: element)
        if isRepresentableMenuBarElement(role: role, frame: frame) {
            stats.representableElementCount += 1
            let snapshot = snapshotBuilder.snapshot(
                for: element,
                ownerName: ownerName,
                bundleIdentifier: bundleIdentifier,
                processIdentifier: processIdentifier,
                role: role
            )

            if snapshot.frame != .zero {
                snapshots.append(snapshot)
                elements[snapshot.id] = MenuBarElementReference(element: element)
            }
        }

        for child in reader.children(of: element) {
            collectItems(
                from: child,
                ownerName: ownerName,
                bundleIdentifier: bundleIdentifier,
                processIdentifier: processIdentifier,
                depth: depth + 1,
                snapshots: &snapshots,
                elements: &elements,
                stats: &stats
            )
        }
    }
}

private extension AXMenuBarScanWorker {
    private func isRepresentableMenuBarElement(role: String, frame: CGRect) -> Bool {
        if role == AXRoleName.menuBarItem {
            return true
        }

        guard role == AXRoleName.button else {
            return false
        }

        return isLikelyMenuBarFrame(frame)
    }

    private func isLikelyMenuBarFrame(_ frame: CGRect) -> Bool {
        guard frame.width > 0, frame.height > 0 else {
            return false
        }

        let bottomOriginMenuBarBandMinY = notchGeometry.screenFrame.maxY - 48
        let isBottomOriginMenuBarFrame = frame.minY >= bottomOriginMenuBarBandMinY
        let isTopOriginMenuBarFrame = frame.minY <= 48

        return (isBottomOriginMenuBarFrame || isTopOriginMenuBarFrame)
            && frame.height <= 40
            && frame.width <= 120
    }

    private func uniqued(_ snapshots: [MenuBarItemSnapshot]) -> [MenuBarItemSnapshot] {
        var seenIDs = Set<MenuBarItemSnapshot.ID>()
        var unique: [MenuBarItemSnapshot] = []

        for snapshot in snapshots where !seenIDs.contains(snapshot.id) {
            seenIDs.insert(snapshot.id)
            unique.append(snapshot)
        }

        return unique
    }
}

private struct MenuBarRoot {
    let element: AXUIElement
    let isExtrasMenuBar: Bool
}
