import CoreGraphics
import Foundation

struct MenuBarItemSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let stableKey: String
    let ownerName: String
    let bundleIdentifier: String?
    let processIdentifier: pid_t
    let title: String
    let role: String
    let subrole: String?
    let frame: CGRect
    let imageData: Data?
    let isNotchCandidate: Bool
    let canPress: Bool

    var displayTitle: String {
        if !title.isEmpty {
            return title
        }

        return ownerName
    }

    var ownerLabel: String {
        bundleIdentifier ?? ownerName
    }

    var shortLabel: String {
        let source = displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = source.first else {
            return "?"
        }

        return String(first).uppercased()
    }

    func withImageData(_ imageData: Data?) -> MenuBarItemSnapshot {
        MenuBarItemSnapshot(
            id: id,
            stableKey: stableKey,
            ownerName: ownerName,
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier,
            title: title,
            role: role,
            subrole: subrole,
            frame: frame,
            imageData: imageData,
            isNotchCandidate: isNotchCandidate,
            canPress: canPress
        )
    }
}
