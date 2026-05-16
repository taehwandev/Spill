import Foundation

enum MenuBarActionAdapter {
    static let providerID = SpillProviderID(rawValue: "menu-bar")
    private static let actionIDPrefix = "menu-bar:"

    static func actions(from snapshots: [MenuBarItemSnapshot]) -> [SpillAction] {
        snapshots.map(action(from:))
    }

    static func action(from snapshot: MenuBarItemSnapshot) -> SpillAction {
        SpillAction(
            id: actionID(for: snapshot),
            title: snapshot.displayTitle,
            subtitle: snapshot.ownerName,
            symbolName: snapshot.imageData == nil ? "app.dashed" : nil,
            iconData: snapshot.imageData,
            kind: .menuBarItem(
                stableKey: snapshot.stableKey,
                bundleIdentifier: snapshot.bundleIdentifier
            ),
            role: snapshot.isNotchCandidate ? .primary : .secondary,
            state: snapshot.canPress ? .enabled : .disabled(reason: "Menu bar item cannot be pressed")
        )
    }

    static func sourceSnapshotID(for action: SpillAction) -> MenuBarItemSnapshot.ID? {
        guard action.id.hasPrefix(actionIDPrefix) else {
            return nil
        }

        return String(action.id.dropFirst(actionIDPrefix.count))
    }

    static func sourceBundleIdentifier(for action: SpillAction) -> String? {
        guard case let .menuBarItem(_, bundleIdentifier) = action.kind else {
            return nil
        }

        return bundleIdentifier
    }

    private static func actionID(for snapshot: MenuBarItemSnapshot) -> String {
        "\(actionIDPrefix)\(snapshot.id)"
    }
}
