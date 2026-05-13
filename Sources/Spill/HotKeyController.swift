import Carbon.HIToolbox
import Foundation

private let spillHotKeySignature: OSType = 0x5350_494C
private let spillHotKeyIDValue: UInt32 = 1

@MainActor
final class HotKeyController {
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var isRegistered: Bool {
        hotKeyRef != nil
    }

    func register() {
        guard hotKeyRef == nil else {
            return
        }

        installEventHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: spillHotKeySignature, id: spillHotKeyIDValue)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            hotKeyRef = nil
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    func stop() {
        unregister()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    fileprivate func handlePressedHotKey() {
        action()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventSpec,
            userData,
            &eventHandlerRef
        )
    }
}

private let hotKeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr,
          hotKeyID.signature == spillHotKeySignature,
          hotKeyID.id == spillHotKeyIDValue
    else {
        return noErr
    }

    let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        controller.handlePressedHotKey()
    }

    return noErr
}
