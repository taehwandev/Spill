import CryptoKit
import Foundation

struct PrivateUsageDailyBucketBuilder: Sendable {
    private let calendar: Calendar
    private let timeZone: TimeZone
    private let sealer: PrivateUsageBucketSealing
    private let encoder: JSONEncoder

    init(
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        sealer: PrivateUsageBucketSealing
    ) {
        var calendar = calendar
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.timeZone = timeZone
        self.sealer = sealer

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
    }

    func makeDirtyDailyBuckets(
        events: [TokenUsageEvent],
        acknowledgedHashesByBucketKey: [String: String],
        now: Date = Date(),
        limit: Int = 31
    ) throws -> [PrivateUsageEncryptedBucket] {
        guard limit > 0 else {
            return []
        }

        let aggregates = makeDailyAggregates(events: events, now: now)
        var buckets = [PrivateUsageEncryptedBucket]()
        buckets.reserveCapacity(min(aggregates.count, limit))

        for aggregate in aggregates {
            let plaintext = try encoder.encode(aggregate)
            let sealed = try sealer.seal(plaintext, bucketKey: aggregate.bucketKey)
            let ciphertextHash = Self.sha256Hex(Data(sealed.ciphertext.utf8))

            if acknowledgedHashesByBucketKey[aggregate.bucketKey] == ciphertextHash {
                continue
            }

            buckets.append(
                PrivateUsageEncryptedBucket(
                    bucketKey: aggregate.bucketKey,
                    bucketKind: aggregate.bucketKind,
                    bucketStartAt: aggregate.bucketStartAt,
                    bucketEndAt: aggregate.bucketEndAt,
                    timezone: aggregate.timezone,
                    schemaVersion: aggregate.schemaVersion,
                    keyVersion: sealed.keyVersion,
                    ciphertext: sealed.ciphertext,
                    ciphertextHash: ciphertextHash
                )
            )

            if buckets.count >= limit {
                break
            }
        }

        return buckets
    }

    func makeDailyAggregates(
        events: [TokenUsageEvent],
        now: Date = Date()
    ) -> [PrivateUsageDailyAggregate] {
        let todayStart = calendar.startOfDay(for: now)
        let groupedEvents = Dictionary(grouping: events.compactMap { event -> (Date, TokenUsageEvent)? in
            guard let date = ISO8601DateFormatter.parseTokenUsageDate(from: event.createdAt),
                  date < todayStart
            else {
                return nil
            }

            return (calendar.startOfDay(for: date), event)
        }) { dayStart, _ in
            dayStart
        }

        return groupedEvents.keys.sorted().compactMap { dayStart -> PrivateUsageDailyAggregate? in
            guard let groupedDayEvents = groupedEvents[dayStart], !groupedDayEvents.isEmpty else {
                return nil
            }

            let dayEvents = groupedDayEvents.map(\.1)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? todayStart
            guard dayEnd <= todayStart else {
                return nil
            }

            return makeAggregate(
                dayStart: dayStart,
                dayEnd: dayEnd,
                events: dayEvents.sorted { lhs, rhs in
                    lhs.createdAt < rhs.createdAt
                },
                generatedAt: now
            )
        }
    }

    private func makeAggregate(
        dayStart: Date,
        dayEnd: Date,
        events: [TokenUsageEvent],
        generatedAt: Date
    ) -> PrivateUsageDailyAggregate {
        var totals = PrivateUsageTokenTotals.zero
        var sourceTotals = [
            "system": 0,
            "user": 0,
            "history": 0,
            "repo_context": 0,
            "tool_output": 0,
            "generated_output": 0,
            "unknown": 0
        ]
        var toolTotals = [String: PrivateUsageTokenTotals]()
        var modelTotals = [String: PrivateUsageTokenTotals]()
        var taskTypeTotals = [String: PrivateUsageTokenTotals]()
        var stageTotals = [String: PrivateUsageTokenTotals]()
        var workflowUsageTotals = PrivateUsageWorkflowUsageTotals.zero

        for event in events {
            totals.add(event)
            add(event, to: &toolTotals, key: event.aiTool.rawValue)
            add(event, to: &modelTotals, key: event.model)
            add(event, to: &taskTypeTotals, key: event.taskType.rawValue)
            add(event, to: &stageTotals, key: event.stage.rawValue)
            workflowUsageTotals.add(event)
            sourceTotals["system", default: 0] += event.tokenBreakdown.system
            sourceTotals["user", default: 0] += event.tokenBreakdown.user
            sourceTotals["history", default: 0] += event.tokenBreakdown.history
            sourceTotals["repo_context", default: 0] += event.tokenBreakdown.repoContext
            sourceTotals["tool_output", default: 0] += event.tokenBreakdown.toolOutput
            sourceTotals["generated_output", default: 0] += event.tokenBreakdown.generatedOutput
            sourceTotals["unknown", default: 0] += event.tokenBreakdown.unknown
        }

        let bucketDay = Self.localDayID(for: dayStart, timeZone: timeZone)
        return PrivateUsageDailyAggregate(
            schemaVersion: 1,
            bucketKind: "daily",
            bucketKey: "\(bucketDay):daily",
            bucketStartAt: Self.localTimestamp(for: dayStart, timeZone: timeZone),
            bucketEndAt: Self.localTimestamp(for: dayEnd, timeZone: timeZone),
            timezone: timeZone.identifier,
            generatedAt: ISO8601DateFormatter.tokenUsage.string(from: generatedAt),
            totals: totals,
            sourceTotals: sourceTotals,
            toolTotals: toolTotals,
            modelTotals: modelTotals,
            taskTypeTotals: taskTypeTotals,
            stageTotals: stageTotals,
            workflowUsageTotals: workflowUsageTotals
        )
    }

    private func add(
        _ event: TokenUsageEvent,
        to totals: inout [String: PrivateUsageTokenTotals],
        key: String
    ) {
        var current = totals[key] ?? .zero
        current.add(event)
        totals[key] = current
    }

    static func localDayID(for date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func localTimestamp(for date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter.string(from: date)
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
