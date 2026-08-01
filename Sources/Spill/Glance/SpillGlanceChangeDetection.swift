import Foundation

// Reactive-rotation change detection. Kept beside the store it extends but in
// its own file: these are pure snapshot-diff rules with no Combine, no
// AppKit, and no view state, and both the store and its tests call them.
extension SpillGlanceStore {
    struct WorkValue: Equatable {
        let id: String
        let value: String
    }

    /// Last rendered values, used to detect what actually moved between snapshots.
    struct ChangeBaseline: Equatable {
        var moduleValues: [SpillGlanceModule: String] = [:]
        /// Ordered highest-usage first, so the winning work change is deterministic.
        var workValues: [WorkValue] = []
    }

    /// One reactive step: the queue after folding in whatever moved between two
    /// snapshots. Pure so the change policy is verifiable without the Combine graph.
    static func advancedQueue(
        _ queue: SpillGlanceChangeQueue,
        reactiveRotationEnabled: Bool,
        didReconfigure: Bool,
        displayStyle: SpillGlanceDisplayStyle,
        workRotationEnabled: Bool,
        items: [SpillGlanceItem],
        previous: ChangeBaseline,
        next: ChangeBaseline,
        at date: Date
    ) -> SpillGlanceChangeQueue {
        // The user reconfigured the surface; a value that "changed" only because
        // the module set or style changed is not a usage event.
        guard !didReconfigure else {
            return SpillGlanceChangeQueue()
        }
        guard reactiveRotationEnabled else {
            return queue
        }

        var queue = queue
        queue.enqueue(
            pendingChanges(
                displayStyle: displayStyle,
                workRotationEnabled: workRotationEnabled,
                items: items,
                previous: previous,
                next: next
            ),
            at: date
        )
        return queue
    }

    static func changeBaseline(
        items: [SpillGlanceItem],
        panelSummary: TokenUsagePanelSummarySnapshot
    ) -> ChangeBaseline {
        var moduleValues: [SpillGlanceModule: String] = [:]
        for item in items where item.module != .workType {
            moduleValues[item.module] = item.value
        }
        return ChangeBaseline(
            moduleValues: moduleValues,
            workValues: orderedWorkValues(panelSummary: panelSummary)
        )
    }

    static func pendingChanges(
        displayStyle: SpillGlanceDisplayStyle,
        workRotationEnabled: Bool,
        items: [SpillGlanceItem],
        previous: ChangeBaseline,
        next: ChangeBaseline
    ) -> [SpillGlanceChangeQueue.Change] {
        var changes: [SpillGlanceChangeQueue.Change] = []

        // `all` keeps every module on screen, so only the Work slot can roll.
        if displayStyle == .ticker {
            for item in items where item.module != .workType {
                guard let previousValue = previous.moduleValues[item.module],
                      let nextValue = next.moduleValues[item.module],
                      previousValue != nextValue
                else {
                    continue
                }
                changes.append(
                    SpillGlanceChangeQueue.Change(module: item.module, value: nextValue)
                )
            }
        }

        guard workRotationEnabled, items.contains(where: { $0.module == .workType }) else {
            return changes
        }

        let previousWorkValues = Dictionary(
            previous.workValues.map { ($0.id, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        // Ordered highest usage first: one Work slot per snapshot, deterministically.
        guard let changedWork = next.workValues.first(where: {
            guard let previousValue = previousWorkValues[$0.id] else {
                return false
            }
            return previousValue != $0.value
        }) else {
            return changes
        }
        changes.append(
            SpillGlanceChangeQueue.Change(module: .workType, value: changedWork.value)
        )
        return changes
    }
}
