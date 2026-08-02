import AppKit

struct SpillGlanceScreenProvider {
    func descriptors() -> [SpillGlanceScreenDescriptor] {
        NSScreen.screens.compactMap(descriptor(for:))
    }

    func preferredDescriptor() -> SpillGlanceScreenDescriptor? {
        (NSScreen.main ?? NSScreen.screens.first).flatMap(descriptor(for:))
    }

    func descriptor(for screen: NSScreen) -> SpillGlanceScreenDescriptor? {
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        guard let screenNumber = screen.deviceDescription[screenNumberKey] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(screenNumber.uint32Value)
        let stableID: String
        if let displayUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
           let displayUUIDString = CFUUIDCreateString(nil, displayUUID) {
            stableID = displayUUIDString as String
        } else {
            stableID = "display-\(displayID)"
        }
        return SpillGlanceScreenDescriptor(id: stableID, visibleFrame: screen.visibleFrame)
    }

    func descriptor(containing pointerLocation: NSPoint) -> SpillGlanceScreenDescriptor? {
        NSScreen.screens.first {
            NSMouseInRect(pointerLocation, $0.frame, false)
        }.flatMap(descriptor(for:))
    }
}
