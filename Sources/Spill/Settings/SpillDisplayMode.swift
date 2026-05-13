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
        switch self {
        case .notchCandidates:
            return scanner.notchCandidates.isEmpty ? scanner.items : scanner.notchCandidates
        case .selectedItems:
            return scanner.items.filter { settings.selectedItemKeys.contains($0.stableKey) }
        case .allDetected:
            return scanner.items
        }
    }
}
