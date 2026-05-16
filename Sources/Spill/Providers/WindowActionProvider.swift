import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct WindowFrameSnapshot: Hashable, Sendable {
    let windowFrame: CGRect
    let visibleFrames: [CGRect]

    var activeVisibleFrame: CGRect? {
        guard !visibleFrames.isEmpty else {
            return nil
        }

        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        return visibleFrames.first { $0.contains(center) }
            ?? visibleFrames.first { $0.intersects(windowFrame) }
            ?? visibleFrames.first
    }
}

enum WindowFramePlanner {
    static func targetFrame(
        for kind: WindowActionKind,
        snapshot: WindowFrameSnapshot,
        restoreFrame: CGRect?
    ) -> CGRect? {
        guard let visibleFrame = snapshot.activeVisibleFrame else {
            return nil
        }

        switch kind {
        case .leftHalf:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            ).integral
        case .rightHalf:
            return CGRect(
                x: visibleFrame.midX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            ).integral
        case .center:
            let size = CGSize(
                width: min(snapshot.windowFrame.width, visibleFrame.width),
                height: min(snapshot.windowFrame.height, visibleFrame.height)
            )
            return CGRect(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.midY - size.height / 2,
                width: size.width,
                height: size.height
            ).integral
        case .maximize:
            return visibleFrame.integral
        case .nextDisplay:
            guard let targetVisibleFrame = nextVisibleFrame(after: visibleFrame, in: snapshot.visibleFrames) else {
                return nil
            }

            let size = CGSize(
                width: min(snapshot.windowFrame.width, targetVisibleFrame.width),
                height: min(snapshot.windowFrame.height, targetVisibleFrame.height)
            )
            return CGRect(
                x: targetVisibleFrame.midX - size.width / 2,
                y: targetVisibleFrame.midY - size.height / 2,
                width: size.width,
                height: size.height
            ).integral
        case .restore:
            return restoreFrame?.integral
        }
    }

    private static func nextVisibleFrame(after current: CGRect, in frames: [CGRect]) -> CGRect? {
        guard frames.count > 1,
              let index = frames.firstIndex(of: current)
        else {
            return nil
        }

        let targetIndex = frames.index(after: index) == frames.endIndex ? frames.startIndex : frames.index(after: index)
        return frames[targetIndex]
    }
}

@MainActor
final class WindowActionStore: ObservableObject {
    @Published private(set) var actions: [SpillAction]

    private let controller: FocusedWindowController
    private var restoreFrame: CGRect?

    init(controller: FocusedWindowController = FocusedWindowController()) {
        self.controller = controller
        actions = Self.makeActions(
            isTrusted: AccessibilityPermission.isTrusted,
            hasFocusedWindow: false,
            canRestore: false,
            canMoveToNextDisplay: NSScreen.screens.count > 1
        )
        refresh()
    }

    func refresh() {
        actions = Self.makeActions(
            isTrusted: AccessibilityPermission.isTrusted,
            hasFocusedWindow: controller.focusedWindowFrame() != nil,
            canRestore: restoreFrame != nil,
            canMoveToNextDisplay: NSScreen.screens.count > 1
        )
    }

    func perform(_ action: SpillAction) -> SpillActionResult {
        guard case let .window(kind) = action.kind else {
            return .unsupported
        }

        let result = controller.perform(kind, restoreFrame: &restoreFrame)
        refresh()
        return result
    }

    private static func makeActions(
        isTrusted: Bool,
        hasFocusedWindow: Bool,
        canRestore: Bool,
        canMoveToNextDisplay: Bool
    ) -> [SpillAction] {
        WindowActionKind.panelOrder.map { kind in
            SpillAction(
                id: "window.\(kind.rawValue)",
                title: kind.title,
                subtitle: kind.subtitle,
                symbolName: kind.symbolName,
                kind: .window(kind),
                role: .secondary,
                state: state(
                    for: kind,
                    isTrusted: isTrusted,
                    hasFocusedWindow: hasFocusedWindow,
                    canRestore: canRestore,
                    canMoveToNextDisplay: canMoveToNextDisplay
                )
            )
        }
    }

    private static func state(
        for kind: WindowActionKind,
        isTrusted: Bool,
        hasFocusedWindow: Bool,
        canRestore: Bool,
        canMoveToNextDisplay: Bool
    ) -> SpillActionState {
        guard isTrusted else {
            return .permissionRequired("Accessibility")
        }

        guard hasFocusedWindow else {
            return .disabled(reason: "No focused window")
        }

        if kind == .restore, !canRestore {
            return .disabled(reason: "No saved frame")
        }

        if kind == .nextDisplay, !canMoveToNextDisplay {
            return .disabled(reason: "One display")
        }

        return .enabled
    }
}

@MainActor
final class FocusedWindowController {
    private let reader = AXElementReader()

    func focusedWindowFrame() -> CGRect? {
        guard let window = focusedWindowElement() else {
            return nil
        }

        let frame = reader.frame(of: window)
        return frame.isUsableWindowFrame ? frame : nil
    }

    func perform(_ kind: WindowActionKind, restoreFrame: inout CGRect?) -> SpillActionResult {
        guard AccessibilityPermission.isTrusted else {
            return .permissionRequired("Accessibility")
        }

        guard let window = focusedWindowElement() else {
            return .unavailable
        }

        let currentFrame = reader.frame(of: window)
        guard currentFrame.isUsableWindowFrame else {
            return .unavailable
        }

        let snapshot = WindowFrameSnapshot(
            windowFrame: currentFrame,
            visibleFrames: NSScreen.screens.map(\.visibleFrame)
        )
        guard let targetFrame = WindowFramePlanner.targetFrame(
            for: kind,
            snapshot: snapshot,
            restoreFrame: restoreFrame
        ) else {
            return .unavailable
        }

        if kind != .restore {
            restoreFrame = currentFrame
        }

        guard reader.setFrame(targetFrame, of: window) else {
            return .failed(message: "Could not move window")
        }

        if kind == .restore {
            restoreFrame = nil
        }

        return .success
    }

    private func focusedWindowElement() -> AXUIElement? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        return reader.elementAttribute(appElement, AXAttributeName.focusedWindow)
    }
}

private extension WindowActionKind {
    static let panelOrder: [WindowActionKind] = [
        .leftHalf,
        .rightHalf,
        .center,
        .maximize,
        .nextDisplay,
        .restore
    ]

    var title: String {
        switch self {
        case .leftHalf:
            return "Left"
        case .rightHalf:
            return "Right"
        case .center:
            return "Center"
        case .maximize:
            return "Max"
        case .nextDisplay:
            return "Next Display"
        case .restore:
            return "Restore"
        }
    }

    var subtitle: String {
        switch self {
        case .leftHalf:
            return "Left half"
        case .rightHalf:
            return "Right half"
        case .center:
            return "Center current size"
        case .maximize:
            return "Fill visible screen"
        case .nextDisplay:
            return "Move to next display"
        case .restore:
            return "Restore previous frame"
        }
    }

    var symbolName: String {
        switch self {
        case .leftHalf:
            return "arrow.left.to.line"
        case .rightHalf:
            return "arrow.right.to.line"
        case .center:
            return "dot.scope"
        case .maximize:
            return "arrow.up.left.and.arrow.down.right"
        case .nextDisplay:
            return "rectangle.on.rectangle"
        case .restore:
            return "arrow.uturn.backward"
        }
    }
}

private extension CGRect {
    var isUsableWindowFrame: Bool {
        width > 0 && height > 0 && isNull == false && isInfinite == false
    }
}
