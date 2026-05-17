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
            if let verticalPlacement = verticalPlacement(of: snapshot.windowFrame, in: visibleFrame) {
                return quarterFrame(in: visibleFrame, horizontal: .leading, vertical: verticalPlacement)
            }

            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            ).integral
        case .rightHalf:
            if let verticalPlacement = verticalPlacement(of: snapshot.windowFrame, in: visibleFrame) {
                return quarterFrame(in: visibleFrame, horizontal: .trailing, vertical: verticalPlacement)
            }

            return CGRect(
                x: visibleFrame.midX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            ).integral
        case .topHalf:
            if let horizontalPlacement = horizontalPlacement(of: snapshot.windowFrame, in: visibleFrame) {
                return quarterFrame(in: visibleFrame, horizontal: horizontalPlacement, vertical: .top)
            }

            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width,
                height: visibleFrame.height / 2
            ).integral
        case .bottomHalf:
            if let horizontalPlacement = horizontalPlacement(of: snapshot.windowFrame, in: visibleFrame) {
                return quarterFrame(in: visibleFrame, horizontal: horizontalPlacement, vertical: .bottom)
            }

            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.midY,
                width: visibleFrame.width,
                height: visibleFrame.height / 2
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
        case .topLeft:
            return quarterFrame(in: visibleFrame, horizontal: .leading, vertical: .top)
        case .topRight:
            return quarterFrame(in: visibleFrame, horizontal: .trailing, vertical: .top)
        case .bottomLeft:
            return quarterFrame(in: visibleFrame, horizontal: .leading, vertical: .bottom)
        case .bottomRight:
            return quarterFrame(in: visibleFrame, horizontal: .trailing, vertical: .bottom)
        case .previousDisplay:
            guard let targetVisibleFrame = previousVisibleFrame(before: visibleFrame, in: snapshot.visibleFrames) else {
                return nil
            }

            return movedFrame(from: snapshot.windowFrame, to: targetVisibleFrame)
        case .nextDisplay:
            guard let targetVisibleFrame = nextVisibleFrame(after: visibleFrame, in: snapshot.visibleFrames) else {
                return nil
            }

            return movedFrame(from: snapshot.windowFrame, to: targetVisibleFrame)
        case .restore:
            return restoreFrame?.integral
        }
    }

    private static func nextVisibleFrame(after current: CGRect, in frames: [CGRect]) -> CGRect? {
        adjacentVisibleFrame(from: current, in: frames, offset: 1)
    }

    private static func previousVisibleFrame(before current: CGRect, in frames: [CGRect]) -> CGRect? {
        adjacentVisibleFrame(from: current, in: frames, offset: -1)
    }

    private static func adjacentVisibleFrame(from current: CGRect, in frames: [CGRect], offset: Int) -> CGRect? {
        guard frames.count > 1,
              offset != 0
        else {
            return nil
        }

        let orderedFrames = frames.sorted { lhs, rhs in
            if lhs.midX == rhs.midX {
                return lhs.midY < rhs.midY
            }

            return lhs.midX < rhs.midX
        }

        guard let index = orderedFrames.firstIndex(of: current) else {
            return nil
        }

        let targetIndex = (index + offset + orderedFrames.count) % orderedFrames.count
        return orderedFrames[targetIndex]
    }

    private static func movedFrame(from windowFrame: CGRect, to visibleFrame: CGRect) -> CGRect {
        let size = CGSize(
            width: min(windowFrame.width, visibleFrame.width),
            height: min(windowFrame.height, visibleFrame.height)
        )
        return CGRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        ).integral
    }

    private static func quarterFrame(
        in visibleFrame: CGRect,
        horizontal: HorizontalPlacement,
        vertical: VerticalPlacement
    ) -> CGRect {
        let width = visibleFrame.width / 2
        let height = visibleFrame.height / 2
        let x = horizontal == .leading ? visibleFrame.minX : visibleFrame.midX
        let y = vertical == .top ? visibleFrame.minY : visibleFrame.midY

        return CGRect(x: x, y: y, width: width, height: height).integral
    }

    private static func horizontalPlacement(
        of windowFrame: CGRect,
        in visibleFrame: CGRect,
        tolerance: CGFloat = 2
    ) -> HorizontalPlacement? {
        guard isApproximately(windowFrame.width, visibleFrame.width / 2, tolerance: tolerance) else {
            return nil
        }

        if isApproximately(windowFrame.minX, visibleFrame.minX, tolerance: tolerance) {
            return .leading
        }

        if isApproximately(windowFrame.minX, visibleFrame.midX, tolerance: tolerance) {
            return .trailing
        }

        return nil
    }

    private static func verticalPlacement(
        of windowFrame: CGRect,
        in visibleFrame: CGRect,
        tolerance: CGFloat = 2
    ) -> VerticalPlacement? {
        guard isApproximately(windowFrame.height, visibleFrame.height / 2, tolerance: tolerance) else {
            return nil
        }

        if isApproximately(windowFrame.minY, visibleFrame.minY, tolerance: tolerance) {
            return .top
        }

        if isApproximately(windowFrame.minY, visibleFrame.midY, tolerance: tolerance) {
            return .bottom
        }

        return nil
    }

    private static func isApproximately(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}

private enum HorizontalPlacement {
    case leading
    case trailing
}

private enum VerticalPlacement {
    case top
    case bottom
}

struct WindowFrameRestoreHistory: Equatable, Sendable {
    private(set) var frames: [CGRect] = []
    private let maxDepth: Int

    init(maxDepth: Int = 20) {
        self.maxDepth = max(1, maxDepth)
    }

    var canRestore: Bool {
        frames.isEmpty == false
    }

    var nextRestoreFrame: CGRect? {
        frames.last
    }

    mutating func record(_ frame: CGRect) {
        frames.append(frame)
        if frames.count > maxDepth {
            frames.removeFirst(frames.count - maxDepth)
        }
    }

    mutating func confirmRestore() {
        _ = frames.popLast()
    }

    mutating func rollbackLatestRecord() {
        _ = frames.popLast()
    }
}

@MainActor
protocol FocusedWindowControlling: AnyObject {
    func focusedWindowFrame() -> CGRect?
    func perform(_ kind: WindowActionKind, restoreHistory: inout WindowFrameRestoreHistory) -> SpillActionResult
}

@MainActor
final class WindowActionStore: ObservableObject {
    typealias AccessibilityTrustReader = () -> Bool

    @Published private(set) var actions: [SpillAction]

    private let controller: FocusedWindowControlling
    private let isAccessibilityTrusted: AccessibilityTrustReader
    private var restoreHistory = WindowFrameRestoreHistory()

    init(
        controller: FocusedWindowControlling = FocusedWindowController(),
        isAccessibilityTrusted: @escaping AccessibilityTrustReader = { AccessibilityPermission.isTrusted }
    ) {
        self.controller = controller
        self.isAccessibilityTrusted = isAccessibilityTrusted
        actions = Self.makeActions(
            isTrusted: isAccessibilityTrusted(),
            hasFocusedWindow: false,
            canRestore: false,
            canMoveBetweenDisplays: NSScreen.screens.count > 1
        )
    }

    func refresh() {
        let isTrusted = isAccessibilityTrusted()
        actions = Self.makeActions(
            isTrusted: isTrusted,
            hasFocusedWindow: isTrusted ? controller.focusedWindowFrame() != nil : false,
            canRestore: restoreHistory.canRestore,
            canMoveBetweenDisplays: NSScreen.screens.count > 1
        )
    }

    func perform(_ action: SpillAction) -> SpillActionResult {
        guard case let .window(kind) = action.kind else {
            return .unsupported
        }

        guard isAccessibilityTrusted() else {
            refresh()
            return .permissionRequired("Accessibility")
        }

        let result = controller.perform(kind, restoreHistory: &restoreHistory)
        refresh()
        return result
    }

    func perform(_ kind: WindowActionKind) -> SpillActionResult {
        guard let action = actions.first(where: { action in
            if case let .window(candidateKind) = action.kind {
                return candidateKind == kind
            }

            return false
        }) else {
            return .unsupported
        }

        return perform(action)
    }

    private static func makeActions(
        isTrusted: Bool,
        hasFocusedWindow: Bool,
        canRestore: Bool,
        canMoveBetweenDisplays: Bool
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
                    canMoveBetweenDisplays: canMoveBetweenDisplays
                )
            )
        }
    }

    private static func state(
        for kind: WindowActionKind,
        isTrusted: Bool,
        hasFocusedWindow: Bool,
        canRestore: Bool,
        canMoveBetweenDisplays: Bool
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

        if kind.isDisplayMove, !canMoveBetweenDisplays {
            return .disabled(reason: "One display")
        }

        return .enabled
    }
}

@MainActor
final class FocusedWindowController: FocusedWindowControlling {
    private let reader = AXElementReader()

    func focusedWindowFrame() -> CGRect? {
        guard let window = focusedWindowElement() else {
            return nil
        }

        let frame = reader.frame(of: window)
        return frame.isUsableWindowFrame ? frame : nil
    }

    func perform(_ kind: WindowActionKind, restoreHistory: inout WindowFrameRestoreHistory) -> SpillActionResult {
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
        let restoreFrame = kind == .restore ? restoreHistory.nextRestoreFrame : nil
        guard let targetFrame = WindowFramePlanner.targetFrame(
            for: kind,
            snapshot: snapshot,
            restoreFrame: restoreFrame
        ) else {
            return .unavailable
        }

        if kind != .restore {
            restoreHistory.record(currentFrame)
        }

        guard reader.setFrame(targetFrame, of: window) else {
            if kind != .restore {
                restoreHistory.rollbackLatestRecord()
            }
            return .failed(message: "Could not move window")
        }

        if kind == .restore {
            restoreHistory.confirmRestore()
        }

        return .success
    }

    private func focusedWindowElement() -> AXUIElement? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        if let focusedWindow = usableWindowElement(from: appElement, attribute: AXAttributeName.focusedWindow) {
            return focusedWindow
        }

        if let mainWindow = usableWindowElement(from: appElement, attribute: AXAttributeName.mainWindow) {
            return mainWindow
        }

        return reader.elementArrayAttribute(appElement, AXAttributeName.windows)
            .first { reader.frame(of: $0).isUsableWindowFrame }
    }

    private func usableWindowElement(from appElement: AXUIElement, attribute: String) -> AXUIElement? {
        guard let window = reader.elementAttribute(appElement, attribute),
              reader.frame(of: window).isUsableWindowFrame
        else {
            return nil
        }

        return window
    }
}

extension WindowActionKind {
    static let panelOrder: [WindowActionKind] = [
        .leftHalf,
        .rightHalf,
        .topHalf,
        .bottomHalf,
        .center,
        .maximize,
        .topLeft,
        .topRight,
        .bottomLeft,
        .bottomRight,
        .previousDisplay,
        .nextDisplay,
        .restore
    ]

    var title: String {
        switch self {
        case .leftHalf:
            return "Left"
        case .rightHalf:
            return "Right"
        case .topHalf:
            return "Top"
        case .bottomHalf:
            return "Bottom"
        case .center:
            return "Center"
        case .maximize:
            return "Max"
        case .topLeft:
            return "Top Left"
        case .topRight:
            return "Top Right"
        case .bottomLeft:
            return "Bottom Left"
        case .bottomRight:
            return "Bottom Right"
        case .previousDisplay:
            return "Display Left"
        case .nextDisplay:
            return "Display Right"
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
        case .topHalf:
            return "Top half"
        case .bottomHalf:
            return "Bottom half"
        case .center:
            return "Center current size"
        case .maximize:
            return "Fill visible screen"
        case .topLeft:
            return "Top-left quarter"
        case .topRight:
            return "Top-right quarter"
        case .bottomLeft:
            return "Bottom-left quarter"
        case .bottomRight:
            return "Bottom-right quarter"
        case .previousDisplay:
            return "Move to left display"
        case .nextDisplay:
            return "Move to right display"
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
        case .topHalf:
            return "arrow.up.to.line"
        case .bottomHalf:
            return "arrow.down.to.line"
        case .center:
            return "dot.scope"
        case .maximize:
            return "arrow.up.left.and.arrow.down.right"
        case .topLeft:
            return "arrow.up.left"
        case .topRight:
            return "arrow.up.right"
        case .bottomLeft:
            return "arrow.down.left"
        case .bottomRight:
            return "arrow.down.right"
        case .previousDisplay:
            return "rectangle.on.rectangle"
        case .nextDisplay:
            return "rectangle.on.rectangle"
        case .restore:
            return "arrow.uturn.backward"
        }
    }

    var isDisplayMove: Bool {
        switch self {
        case .previousDisplay, .nextDisplay:
            return true
        case .leftHalf,
             .rightHalf,
             .topHalf,
             .bottomHalf,
             .center,
             .maximize,
             .topLeft,
             .topRight,
             .bottomLeft,
             .bottomRight,
             .restore:
            return false
        }
    }
}

private extension CGRect {
    var isUsableWindowFrame: Bool {
        width > 0 && height > 0 && isNull == false && isInfinite == false
    }
}
