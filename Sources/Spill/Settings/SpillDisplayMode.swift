import Foundation

enum SpillDisplayMode: String, CaseIterable, Identifiable {
    case notchCandidates
    case selectedItems
    case allDetected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notchCandidates:
            return "Notch Candidates"
        case .selectedItems:
            return "Selected"
        case .allDetected:
            return "All Detected"
        }
    }

    @MainActor
    func items(from scanner: AXMenuBarItemScanner, settings: SpillSettings = .shared) -> [MenuBarItemSnapshot] {
        let visibleItems = scanner.items.filter { !settings.isItemHidden($0) }

        switch self {
        case .notchCandidates:
            return Self.notchCandidateItems(from: scanner, settings: settings)
        case .selectedItems:
            return visibleItems.filter { settings.selectedItemKeys.contains($0.stableKey) }
        case .allDetected:
            return visibleItems
        }
    }

    @MainActor
    static func notchCandidateItems(
        from scanner: AXMenuBarItemScanner,
        settings: SpillSettings = .shared
    ) -> [MenuBarItemSnapshot] {
        scanner.notchCandidates.filter { !settings.isItemHidden($0) }
    }
}
