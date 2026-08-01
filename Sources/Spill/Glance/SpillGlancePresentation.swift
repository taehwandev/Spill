import Foundation

struct SpillGlancePresentation: Equatable {
    struct LayoutSignature: Equatable {
        let modules: [SpillGlanceModule]
        let displayStyle: SpillGlanceDisplayStyle
    }

    /// Render schedule the surface needs, expressed without importing SwiftUI.
    enum RotationSchedule: Equatable {
        case none
        case periodic(from: Date, interval: TimeInterval)
        case explicit([Date])
    }

    let isVisible: Bool
    let items: [SpillGlanceItem]
    let displayStyle: SpillGlanceDisplayStyle
    let showInFullScreen: Bool
    let reactiveRotationEnabled: Bool
    let rotationEpoch: Date
    let changeQueue: SpillGlanceChangeQueue

    init(
        isVisible: Bool,
        items: [SpillGlanceItem],
        displayStyle: SpillGlanceDisplayStyle,
        showInFullScreen: Bool,
        reactiveRotationEnabled: Bool = false,
        rotationEpoch: Date,
        changeQueue: SpillGlanceChangeQueue = SpillGlanceChangeQueue()
    ) {
        self.isVisible = isVisible
        self.items = items
        self.displayStyle = displayStyle
        self.showInFullScreen = showInFullScreen
        self.reactiveRotationEnabled = reactiveRotationEnabled
        self.rotationEpoch = rotationEpoch
        self.changeQueue = changeQueue
    }

    var layoutSignature: LayoutSignature {
        LayoutSignature(
            modules: displayStyle == .ticker ? [] : items.map(\.module),
            displayStyle: displayStyle
        )
    }

    static func hidden(
        displayStyle: SpillGlanceDisplayStyle,
        showInFullScreen: Bool,
        reactiveRotationEnabled: Bool = false,
        rotationEpoch: Date
    ) -> SpillGlancePresentation {
        SpillGlancePresentation(
            isVisible: false,
            items: [],
            displayStyle: displayStyle,
            showInFullScreen: showInFullScreen,
            reactiveRotationEnabled: reactiveRotationEnabled,
            rotationEpoch: rotationEpoch
        )
    }

    var rotationSchedule: RotationSchedule {
        guard isVisible, !items.isEmpty else {
            return .none
        }
        guard !reactiveRotationEnabled else {
            let boundaries = changeQueue.boundaries
            return boundaries.isEmpty ? .none : .explicit(boundaries)
        }
        guard requiresRollingRotation else {
            return .none
        }
        return .periodic(
            from: rotationEpoch,
            interval: SpillGlanceItem.rotationInterval
        )
    }

    var requiresRotation: Bool {
        rotationSchedule != .none
    }

    func visibleItems(at date: Date) -> [SpillGlanceItem] {
        guard !items.isEmpty else {
            return []
        }
        return reactiveRotationEnabled
            ? reactiveItems(at: date)
            : rollingItems(at: date)
    }
}

private extension SpillGlancePresentation {
    var requiresRollingRotation: Bool {
        switch displayStyle {
        case .all:
            return items.contains { $0.displayValues.count > 1 }
        case .ticker:
            return items.count > 1 || items.contains { $0.displayValues.count > 1 }
        }
    }

    /// Only what just changed rolls. While the queue is quiet the ticker rests on
    /// today's total and the `all` Work cell rests on the highest-usage type.
    func reactiveItems(at date: Date) -> [SpillGlanceItem] {
        switch displayStyle {
        case .all:
            return items.map { item in
                guard item.module == .workType else {
                    return item
                }
                let value = changeQueue.entry(for: .workType, at: date)?.value ?? item.value
                return item.singleValue(value)
            }
        case .ticker:
            if let entry = changeQueue.entry(at: date),
               let item = items.first(where: { $0.module == entry.module }) {
                return [item.singleValue(entry.value)]
            }
            let restingItem = items.first { $0.module == .allToday } ?? items[0]
            return [restingItem.singleValue(restingItem.value)]
        }
    }

    func rollingItems(at date: Date) -> [SpillGlanceItem] {
        guard displayStyle == .ticker else {
            return items
        }

        let elapsed = max(0, date.timeIntervalSince(rotationEpoch))
        let tick = Int(elapsed / SpillGlanceItem.rotationInterval)
        let item = items[tick % items.count]
        let completedCycles = tick / items.count
        let value = item.displayValues[completedCycles % item.displayValues.count]
        return [item.singleValue(value)]
    }
}
