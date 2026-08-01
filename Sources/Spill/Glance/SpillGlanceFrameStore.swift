import AppKit

struct SpillGlanceFrameStore {
    private let defaults: UserDefaults
    private let placementKey = "spillGlancePlacementV2"
    private let legacyFrameKey = "spillGlanceFrame"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Rewrites a pre-anchor absolute frame into an anchored placement. Separate
    /// from `restoredFrame` so the read path stays free of persistence writes; the
    /// caller runs it before restoring, while the original display is connected.
    func migrateLegacyPlacementIfNeeded(displays: [SpillGlanceScreenDescriptor]) {
        guard savedPlacement == nil,
              let legacyFrame,
              let legacyDisplay = displays.first(where: {
                  $0.visibleFrame.contains(CGPoint(x: legacyFrame.midX, y: legacyFrame.midY))
              })
        else {
            return
        }

        save(SpillGlancePlacement.capture(frame: legacyFrame, display: legacyDisplay))
        defaults.removeObject(forKey: legacyFrameKey)
    }

    func restoredFrame(
        displays: [SpillGlanceScreenDescriptor],
        fallbackDisplay: SpillGlanceScreenDescriptor?,
        contentSize: CGSize
    ) -> NSRect {
        guard let resolvedFallback = fallbackDisplay ?? displays.first else {
            return .zero
        }

        guard let savedPlacement else {
            return SpillGlanceLayout.panelFrame(
                contentSize: contentSize,
                visibleFrame: resolvedFallback.visibleFrame
            )
        }

        let targetDisplay = displays.first { $0.id == savedPlacement.displayID }
            ?? resolvedFallback
        return savedPlacement.frame(
            contentSize: contentSize,
            visibleFrame: targetDisplay.visibleFrame
        )
    }

    func save(_ frame: NSRect, display: SpillGlanceScreenDescriptor) {
        guard frame.width.isFinite,
              frame.height.isFinite,
              frame.minX.isFinite,
              frame.minY.isFinite,
              frame.width > 0,
              frame.height > 0
        else {
            return
        }

        save(SpillGlancePlacement.capture(frame: frame, display: display))
    }

    private var savedPlacement: SpillGlancePlacement? {
        guard let data = defaults.data(forKey: placementKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SpillGlancePlacement.self, from: data)
    }

    private var legacyFrame: NSRect? {
        guard let value = defaults.string(forKey: legacyFrameKey) else {
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

    private func save(_ placement: SpillGlancePlacement) {
        guard let data = try? JSONEncoder().encode(placement) else {
            return
        }
        defaults.set(data, forKey: placementKey)
    }
}
