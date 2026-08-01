import SwiftUI

/// One schedule type for both rotation models, so the surface keeps a single
/// `TimelineView`. Rolling rotation ticks on a fixed period; reactive rotation
/// only redraws at the boundaries of the queued changes and then stops, which is
/// why an explicit date list is used instead of a period.
struct SpillGlanceRotationTimelineSchedule: TimelineSchedule {
    let rotation: SpillGlancePresentation.RotationSchedule

    func entries(from startDate: Date, mode: Mode) -> AnyIterator<Date> {
        switch rotation {
        case .none:
            return Self.singleEntry(startDate)
        case let .periodic(from, interval):
            guard interval > 0 else {
                return Self.singleEntry(startDate)
            }
            let steps = (startDate.timeIntervalSince(from) / interval).rounded(.down)
            var next = from.addingTimeInterval(steps * interval)
            return AnyIterator {
                defer { next = next.addingTimeInterval(interval) }
                return next
            }
        case let .explicit(dates):
            let sorted = dates.sorted()
            guard let firstIndex = sorted.lastIndex(where: { $0 <= startDate }) else {
                // TimelineView needs an entry at or before `startDate` to render now.
                var iterator = (CollectionOfOne(startDate) + sorted).makeIterator()
                return AnyIterator { iterator.next() }
            }
            var iterator = sorted[firstIndex...].makeIterator()
            return AnyIterator { iterator.next() }
        }
    }

    private static func singleEntry(_ date: Date) -> AnyIterator<Date> {
        var next: Date? = date
        return AnyIterator {
            defer { next = nil }
            return next
        }
    }
}
