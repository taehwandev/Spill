import ApplicationServices
import Foundation

struct MenuBarItemSnapshotBuilder {
    private let notchDetector: NotchDetector
    private let reader = AXElementReader()

    init(notchGeometry: MenuBarNotchGeometry) {
        notchDetector = NotchDetector(geometry: notchGeometry)
    }

    func snapshot(
        for element: AXUIElement,
        ownerName: String,
        bundleIdentifier: String?,
        processIdentifier: pid_t,
        role: String
    ) -> MenuBarItemSnapshot {
        let title = reader.stringAttribute(element, AXAttributeName.title)
            ?? reader.stringAttribute(element, AXAttributeName.description)
            ?? ""
        let subrole = reader.stringAttribute(element, AXAttributeName.subrole)
        let frame = reader.frame(of: element)
        let canPress = reader.actionNames(for: element).contains(AXActionName.press)
        let id = makeID(
            ownerName: ownerName,
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier,
            title: title,
            frame: frame
        )
        let stableKey = makeStableKey(
            ownerName: ownerName,
            bundleIdentifier: bundleIdentifier,
            title: title,
            role: role,
            subrole: subrole
        )

        return MenuBarItemSnapshot(
            id: id,
            stableKey: stableKey,
            ownerName: ownerName,
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier,
            title: title,
            role: role,
            subrole: subrole,
            frame: frame,
            imageData: nil,
            isNotchCandidate: notchDetector.intersectsNotchEstimate(frame),
            canPress: canPress
        )
    }

    private func makeID(
        ownerName: String,
        bundleIdentifier: String?,
        processIdentifier: pid_t,
        title: String,
        frame: CGRect
    ) -> String {
        [
            "\(processIdentifier)",
            bundleIdentifier ?? ownerName,
            ownerName,
            title,
            "\(Int(frame.minX.rounded()))",
            "\(Int(frame.minY.rounded()))",
            "\(Int(frame.width.rounded()))",
            "\(Int(frame.height.rounded()))"
        ].joined(separator: ":")
    }

    private func makeStableKey(
        ownerName: String,
        bundleIdentifier: String?,
        title: String,
        role: String,
        subrole: String?
    ) -> String {
        [
            bundleIdentifier ?? ownerName,
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            role,
            subrole ?? ""
        ].joined(separator: "::")
    }
}
