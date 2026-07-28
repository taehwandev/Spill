import AppKit

struct SpillGlanceFrameStore {
    private let defaults: UserDefaults
    private let key = "spillGlanceFrame"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func restoredFrame(visibleFrame: NSRect, fallback: NSRect) -> NSRect {
        restoredFrame(visibleFrames: [visibleFrame], fallback: fallback)
    }

    func restoredFrame(visibleFrames: [NSRect], fallback: NSRect) -> NSRect {
        guard let savedFrame else {
            return fallback
        }
        let savedCenter = NSPoint(x: savedFrame.midX, y: savedFrame.midY)
        guard let visibleFrame = visibleFrames.first(where: { $0.contains(savedCenter) }) else {
            return fallback
        }

        let resizedFrame = NSRect(
            x: savedFrame.midX - (fallback.width / 2),
            y: savedFrame.midY - (fallback.height / 2),
            width: fallback.width,
            height: fallback.height
        )
        return SpillGlanceLayout.constrainedFrame(
            resizedFrame,
            visibleFrame: visibleFrame
        )
    }

    func save(_ frame: NSRect) {
        guard frame.width.isFinite,
              frame.height.isFinite,
              frame.minX.isFinite,
              frame.minY.isFinite,
              frame.width > 0,
              frame.height > 0
        else {
            return
        }

        defaults.set(NSStringFromRect(frame), forKey: key)
    }

    private var savedFrame: NSRect? {
        guard let value = defaults.string(forKey: key) else {
            return nil
        }

        let frame = NSRectFromString(value)
        guard frame.width.isFinite,
              frame.height.isFinite,
              frame.minX.isFinite,
              frame.minY.isFinite,
              frame.width > 0,
              frame.height > 0
        else {
            return nil
        }

        return frame
    }
}
