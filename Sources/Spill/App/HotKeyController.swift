import Carbon.HIToolbox
import Foundation

private let spillHotKeySignature: OSType = 0x5350_494C

struct HotKeyRegistration {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
    let action: @MainActor @Sendable () -> Void
}

@MainActor
final class HotKeyController {
    private var registrations: [HotKeyRegistration]
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?

    init(action: @escaping @MainActor @Sendable () -> Void) {
        self.registrations = [
            HotKeyRegistration(
                id: 1,
                keyCode: UInt32(kVK_Space),
                modifiers: UInt32(controlKey | optionKey),
                action: action
            )
        ]
    }

    init(registrations: [HotKeyRegistration]) {
        self.registrations = registrations
    }

    var isRegistered: Bool {
        !hotKeyRefs.isEmpty
    }

    func updateRegistrations(_ registrations: [HotKeyRegistration]) {
        let shouldRegister = isRegistered
        unregister()
        self.registrations = registrations

        if shouldRegister {
            register()
        }
    }

    func register() {
        installEventHandlerIfNeeded()

        for registration in registrations where hotKeyRefs[registration.id] == nil {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: spillHotKeySignature, id: registration.id)
            let status = RegisterEventHotKey(
                registration.keyCode,
                registration.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr, let hotKeyRef {
                hotKeyRefs[registration.id] = hotKeyRef
            }
        }
    }

    func unregister() {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }

        hotKeyRefs.removeAll()
    }

    func stop() {
        unregister()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    fileprivate func handlePressedHotKey(id: UInt32) {
        guard let registration = registrations.first(where: { $0.id == id }) else {
            return
        }

        registration.action()
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
          hotKeyID.signature == spillHotKeySignature
    else {
        return noErr
    }

    let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        controller.handlePressedHotKey(id: hotKeyID.id)
    }

    return noErr
}

extension HotKeyRegistration {
    static func spillDefaults(
        windowActionShortcutKeys: [WindowActionKind: WindowActionShortcutKey],
        toggleAction: @escaping @MainActor @Sendable () -> Void,
        windowAction: @escaping @MainActor @Sendable (WindowActionKind) -> Void
    ) -> [HotKeyRegistration] {
        let panelRegistration = [
            HotKeyRegistration(
                id: 1,
                keyCode: UInt32(kVK_Space),
                modifiers: UInt32(controlKey | optionKey),
                action: toggleAction
            )
        ]
        let windowRegistrations = WindowActionKind.panelOrder.compactMap { kind -> HotKeyRegistration? in
            let shortcutKey = windowActionShortcutKeys[kind] ?? kind.defaultShortcutKey
            guard let keyCode = shortcutKey.keyCode else {
                return nil
            }

            return HotKeyRegistration(
                id: kind.hotKeyID,
                keyCode: keyCode,
                modifiers: UInt32(controlKey | optionKey),
                action: { windowAction(kind) }
            )
        }

        return panelRegistration + windowRegistrations
    }
}
