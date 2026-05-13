import AppKit

struct SpillPanelFrameStore {
    private let defaults: UserDefaults
    private let key = "spillPanelFrame"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func restoredFrame(visibleFrame: NSRect, fallback: NSRect) -> NSRect {
        guard let savedFrame else {
            return fallback
        }

        return savedFrame.constrained(
            to: visibleFrame,
            minimumSize: SpillPanelMetrics.minimumSize,
            edgeInset: SpillPanelMetrics.edgeInset
        )
    }

    func save(_ frame: NSRect) {
        defaults.set(NSStringFromRect(frame), forKey: key)
    }

    private var savedFrame: NSRect? {
        guard let value = defaults.string(forKey: key) else {
            return nil
        }

        let frame = NSRectFromString(value)
        guard frame.width.isFinite, frame.height.isFinite, frame.width > 0, frame.height > 0 else {
            return nil
        }

        return frame
    }
}
