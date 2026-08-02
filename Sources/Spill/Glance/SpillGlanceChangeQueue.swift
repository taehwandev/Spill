import Foundation

/// Throttled queue of "this module's value just changed" events.
///
/// Reactive rotation surfaces only what actually moved instead of cycling every
/// module on a fixed schedule. Each change owns a fixed dwell window, and a
/// module that keeps changing inside its own window updates that window in place
/// instead of appending another one. That coalescing is the throttle: a burst of
/// usage events can never queue more than one slot per module, so the queue is
/// bounded by the module count and never runs away from the current time.
struct SpillGlanceChangeQueue: Equatable {
    struct Change: Equatable {
        let module: SpillGlanceModule
        let value: String
    }

    struct Entry: Equatable {
        let module: SpillGlanceModule
        let value: String
        let start: Date
        let end: Date
    }

    static let dwell: TimeInterval = SpillGlanceItem.rotationInterval

    private(set) var entries: [Entry]

    init(entries: [Entry] = []) {
        self.entries = entries
    }

    /// Boundaries where the visible entry changes, for an explicit render schedule.
    var boundaries: [Date] {
        var dates: [Date] = []
        for entry in entries {
            if dates.last != entry.start {
                dates.append(entry.start)
            }
            dates.append(entry.end)
        }
        return dates
    }

    func entry(at date: Date) -> Entry? {
        entries.first { $0.start <= date && date < $0.end }
    }

    func entry(for module: SpillGlanceModule, at date: Date) -> Entry? {
        guard let entry = entry(at: date), entry.module == module else {
            return nil
        }
        return entry
    }

    mutating func enqueue(
        _ changes: [Change],
        at date: Date,
        dwell: TimeInterval = dwell
    ) {
        entries.removeAll { $0.end <= date }
        guard dwell > 0 else {
            return
        }

        for change in changes {
            if let index = entries.firstIndex(where: { $0.module == change.module }) {
                let pending = entries[index]
                entries[index] = Entry(
                    module: pending.module,
                    value: change.value,
                    start: pending.start,
                    end: pending.end
                )
                continue
            }

            let start = max(date, entries.last?.end ?? date)
            entries.append(
                Entry(
                    module: change.module,
                    value: change.value,
                    start: start,
                    end: start.addingTimeInterval(dwell)
                )
            )
        }
    }
}
