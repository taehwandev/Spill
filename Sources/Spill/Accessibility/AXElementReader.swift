import ApplicationServices
import CoreGraphics
import Foundation

struct AXElementReader: Sendable {
    private let messagingTimeout: Float = 0.08

    func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        prepare(element)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return (value as! AXUIElement)
    }

    func children(of element: AXUIElement) -> [AXUIElement] {
        prepare(element)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, AXAttributeName.children as CFString, &value) == .success,
              let value
        else {
            return []
        }

        return value as? [AXUIElement] ?? []
    }

    func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        prepare(element)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        return value as? String
    }

    func frame(of element: AXUIElement) -> CGRect {
        guard let position = pointAttribute(element, AXAttributeName.position),
              let size = sizeAttribute(element, AXAttributeName.size)
        else {
            return .zero
        }

        return CGRect(origin: position, size: size)
    }

    func setFrame(_ frame: CGRect, of element: AXUIElement) -> Bool {
        setSize(frame.size, for: element, attribute: AXAttributeName.size)
            && setPosition(frame.origin, for: element, attribute: AXAttributeName.position)
    }

    func actionNames(for element: AXUIElement) -> [String] {
        prepare(element)

        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else {
            return []
        }

        return names as? [String] ?? []
    }

    func performPress(on element: AXUIElement) -> AXError {
        prepare(element)
        return AXUIElementPerformAction(element, AXActionName.press as CFString)
    }

    private func pointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        prepare(element)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else {
            return nil
        }

        return point
    }

    private func sizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        prepare(element)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else {
            return nil
        }

        return size
    }

    private func setPosition(_ point: CGPoint, for element: AXUIElement, attribute: String) -> Bool {
        prepare(element)

        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else {
            return false
        }

        return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
    }

    private func setSize(_ size: CGSize, for element: AXUIElement, attribute: String) -> Bool {
        prepare(element)

        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else {
            return false
        }

        return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
    }

    private func prepare(_ element: AXUIElement) {
        _ = AXUIElementSetMessagingTimeout(element, messagingTimeout)
    }
}
