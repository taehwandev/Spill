import AppKit
import ApplicationServices
import Foundation

struct SpillPanelAccessibilityReport: Equatable {
    static let defaultRequiredLabels = [
        "Spill Flow",
        "AI",
        "WINDOWS",
        "MENU BAR",
        "Sleep Guard Off"
    ]

    let requiredLabels: [String]
    let discoveredLabels: [String]

    init(
        requiredLabels: [String] = Self.defaultRequiredLabels,
        discoveredLabels: [String]
    ) {
        self.requiredLabels = requiredLabels
        self.discoveredLabels = Self.uniqueLabels(discoveredLabels)
    }

    @MainActor init(
        rootElement: AnyObject?,
        requiredLabels: [String] = Self.defaultRequiredLabels
    ) {
        self.requiredLabels = requiredLabels

        guard let rootElement else {
            discoveredLabels = []
            return
        }

        discoveredLabels = Self.uniqueLabels(
            Self.collectLabels(from: rootElement) + Self.collectCurrentApplicationAXLabels()
        )
    }

    var missingLabels: [String] {
        requiredLabels.filter { requiredLabel in
            !discoveredLabels.contains { discoveredLabel in
                Self.label(discoveredLabel, satisfies: requiredLabel)
            }
        }
    }

    var isValid: Bool {
        missingLabels.isEmpty
    }

    var logLine: String {
        [
            "required=\(Self.format(labels: requiredLabels))",
            "discovered=\(Self.format(labels: discoveredLabels))",
            "missing=\(Self.format(labels: missingLabels))",
            "valid=\(isValid)"
        ].joined(separator: " ")
    }

    @MainActor private static func collectLabels(from rootElement: AnyObject) -> [String] {
        var labels = [String]()
        var visited = Set<ObjectIdentifier>()
        collectLabels(from: rootElement, depth: 0, visited: &visited, labels: &labels)
        return labels
    }

    @MainActor private static func collectLabels(
        from element: AnyObject,
        depth: Int,
        visited: inout Set<ObjectIdentifier>,
        labels: inout [String]
    ) {
        guard depth <= 32 else {
            return
        }

        let identifier = ObjectIdentifier(element)
        guard visited.insert(identifier).inserted else {
            return
        }

        if let accessibleElement = element as? NSObject {
            append(stringAttribute("accessibilityLabel", from: accessibleElement), to: &labels)
            append(stringAttribute("accessibilityTitle", from: accessibleElement), to: &labels)
            append(stringAttribute("accessibilityIdentifier", from: accessibleElement), to: &labels)
            append(stringAttribute("accessibilityValue", from: accessibleElement), to: &labels)

            if let children = arrayAttribute("accessibilityChildren", from: accessibleElement) {
                for child in NSAccessibility.unignoredChildren(from: children) {
                    collectLabelsIfPossible(
                        from: child,
                        depth: depth + 1,
                        visited: &visited,
                        labels: &labels
                    )
                }
            }

            if let contents = arrayAttribute("accessibilityContents", from: accessibleElement) {
                for child in contents {
                    collectLabelsIfPossible(
                        from: child,
                        depth: depth + 1,
                        visited: &visited,
                        labels: &labels
                    )
                }
            }
        }

        if let view = element as? NSView {
            for subview in view.subviews {
                collectLabels(
                    from: subview,
                    depth: depth + 1,
                    visited: &visited,
                    labels: &labels
                )
            }
        }
    }

    private static func stringAttribute(_ name: String, from object: NSObject) -> String? {
        performedValue(name, from: object) as? String
    }

    private static func arrayAttribute(_ name: String, from object: NSObject) -> [Any]? {
        performedValue(name, from: object) as? [Any]
    }

    private static func performedValue(_ selectorName: String, from object: NSObject) -> Any? {
        let selector = NSSelectorFromString(selectorName)
        guard object.responds(to: selector),
              let value = object.perform(selector)
        else {
            return nil
        }

        return value.takeUnretainedValue()
    }

    private static func collectCurrentApplicationAXLabels() -> [String] {
        let appElement = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        var labels = [String]()
        var visited = Set<CFHashCode>()
        collectAXLabels(from: appElement, depth: 0, visited: &visited, labels: &labels)
        return labels
    }

    private static func collectAXLabels(
        from element: AXUIElement,
        depth: Int,
        visited: inout Set<CFHashCode>,
        labels: inout [String]
    ) {
        guard depth <= 32 else {
            return
        }

        let identifier = CFHash(element)
        guard visited.insert(identifier).inserted else {
            return
        }

        for attribute in axStringAttributes {
            append(axStringAttribute(attribute, from: element), to: &labels)
        }

        for attribute in axArrayAttributes {
            guard let children = axArrayAttribute(attribute, from: element) else {
                continue
            }

            for child in children {
                collectAXLabels(
                    from: child,
                    depth: depth + 1,
                    visited: &visited,
                    labels: &labels
                )
            }
        }
    }

    private static func axStringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        guard error == .success, let value else {
            return nil
        }

        if let string = value as? String {
            return string
        }

        if let attributedString = value as? NSAttributedString {
            return attributedString.string
        }

        return nil
    }

    private static func axArrayAttribute(_ attribute: String, from element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        guard error == .success, let array = value as? [AnyObject] else {
            return nil
        }

        return array.compactMap { object in
            guard CFGetTypeID(object) == AXUIElementGetTypeID() else {
                return nil
            }

            return (object as! AXUIElement)
        }
    }

    @MainActor private static func collectLabelsIfPossible(
        from element: Any,
        depth: Int,
        visited: inout Set<ObjectIdentifier>,
        labels: inout [String]
    ) {
        guard let object = element as AnyObject? else {
            return
        }

        collectLabels(from: object, depth: depth, visited: &visited, labels: &labels)
    }

    private static func append(_ label: String?, to labels: inout [String]) {
        guard let normalized = normalizedLabel(label), !normalized.isEmpty else {
            return
        }

        labels.append(normalized)
    }

    private static func uniqueLabels(_ labels: [String]) -> [String] {
        var seen = Set<String>()
        var result = [String]()

        for label in labels {
            guard let normalized = normalizedLabel(label) else {
                continue
            }

            let key = normalized.lowercased()
            if seen.insert(key).inserted {
                result.append(normalized)
            }
        }

        return result
    }

    private static func label(_ discoveredLabel: String, satisfies requiredLabel: String) -> Bool {
        guard let discovered = normalizedLabel(discoveredLabel)?.lowercased(),
              let required = normalizedLabel(requiredLabel)?.lowercased()
        else {
            return false
        }

        return discovered == required
            || discovered.hasPrefix("\(required) ")
            || discovered.hasSuffix(" \(required)")
            || discovered.contains(" \(required) ")
    }

    private static func normalizedLabel(_ label: String?) -> String? {
        label?
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func format(labels: [String]) -> String {
        guard !labels.isEmpty else {
            return "none"
        }

        return labels.map(logToken(for:)).joined(separator: ",")
    }

    private static func logToken(for label: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var result = ""

        for scalar in label.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                result.append("_")
            } else if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else {
                result.append("-")
            }
        }

        return result.isEmpty ? "empty" : result
    }

    private static let axStringAttributes = [
        kAXDescriptionAttribute,
        kAXTitleAttribute,
        kAXValueAttribute,
        kAXHelpAttribute
    ]

    private static let axArrayAttributes = [
        kAXWindowsAttribute,
        kAXChildrenAttribute,
        kAXVisibleChildrenAttribute,
        kAXContentsAttribute
    ]
}
