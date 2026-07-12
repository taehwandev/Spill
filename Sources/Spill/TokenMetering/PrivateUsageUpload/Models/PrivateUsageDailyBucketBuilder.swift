import Foundation

struct PrivateUsageDailyBucketBuilder: Sendable {
    let calendar: Calendar
    let timeZone: TimeZone
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
}

extension PrivateUsageDailyBucketBuilder {
    func makeDirtyDailyBuckets(
        events: [TokenUsageEvent],
        acknowledgedHashesByBucketKey: [String: String],
        now: Date = Date(),
        limit: Int = 31,
        earliestBucketStart: Date? = nil,
        includeCurrentDay: Bool = false,
        requiredDayIDs: [String] = []
    ) throws -> [PrivateUsageEncryptedBucket] {
        guard limit > 0 else {
            return []
        }

        let aggregates = makeDailyAggregates(
            events: events,
            now: now,
            earliestBucketStart: earliestBucketStart,
            includeCurrentDay: includeCurrentDay,
            requiredDayIDs: requiredDayIDs
        )
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

    func makeDirtySharedSummaries(
        events: [TokenUsageEvent],
        acknowledgedHashesByBucketKey: [String: String],
        now: Date = Date(),
        limit: Int = 31,
        earliestBucketStart: Date? = nil,
        includeCurrentDay: Bool = false,
        requiredDayIDs: [String] = []
    ) throws -> [PrivateUsageSharedSummary] {
        guard limit > 0 else {
            return []
        }

        let aggregates = makeDailyAggregates(
            events: events,
            now: now,
            earliestBucketStart: earliestBucketStart,
            includeCurrentDay: includeCurrentDay,
            requiredDayIDs: requiredDayIDs
        )
        var summaries = [PrivateUsageSharedSummary]()
        summaries.reserveCapacity(min(aggregates.count, limit))

        for aggregate in aggregates {
            let summary = PrivateUsageSharedSummary(aggregate: aggregate)
            let summaryHash = try summary.canonicalHash()
            if acknowledgedHashesByBucketKey[summary.bucketKey] == summaryHash {
                continue
            }

            summaries.append(summary)

            if summaries.count >= limit {
                break
            }
        }

        return summaries
    }
}

extension PrivateUsageDailyBucketBuilder {
    func makeDailyAggregates(
        events: [TokenUsageEvent],
        now: Date = Date(),
        earliestBucketStart: Date? = nil,
        includeCurrentDay: Bool = false,
        requiredDayIDs: [String] = []
    ) -> [PrivateUsageDailyAggregate] {
        let todayStart = calendar.startOfDay(for: now)
        let earliestDayStart = earliestBucketStart.map { calendar.startOfDay(for: $0) }
        let deduplicatedEvents = Self.deduplicateByContent(events)
        let groupedEvents = Dictionary(grouping: deduplicatedEvents.compactMap { event -> (Date, TokenUsageEvent)? in
            guard let date = ISO8601DateFormatter.parseTokenUsageDate(from: event.createdAt),
                  date < todayStart || (includeCurrentDay && date <= now)
            else {
                return nil
            }

            let dayStart = calendar.startOfDay(for: date)
            if let earliestDayStart,
               dayStart < earliestDayStart
            {
                return nil
            }

            return (dayStart, event)
        }) { dayStart, _ in
            dayStart
        }

        var aggregates = groupedEvents.keys.sorted().compactMap { dayStart -> PrivateUsageDailyAggregate? in
            guard let groupedDayEvents = groupedEvents[dayStart], !groupedDayEvents.isEmpty else {
                return nil
            }

            let dayEvents = groupedDayEvents.map(\.1)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? todayStart
            guard includeCurrentDay || dayEnd <= todayStart else {
                return nil
            }

            let generatedAt = dayEvents.compactMap {
                ISO8601DateFormatter.parseTokenUsageDate(from: $0.createdAt)
            }.max() ?? dayEnd

            return makeAggregate(
                dayStart: dayStart,
                dayEnd: dayEnd,
                events: dayEvents.sorted(by: Self.eventPrecedes),
                generatedAt: generatedAt
            )
        }

        var existingDayIDs = Set(aggregates.map { String($0.bucketKey.prefix(10)) })
        for dayID in requiredDayIDs.sorted() where !existingDayIDs.contains(dayID) {
            guard let interval = localDayInterval(for: dayID),
                  interval.start < todayStart || (includeCurrentDay && interval.start <= now)
            else {
                continue
            }
            if let earliestDayStart,
               interval.start < earliestDayStart
            {
                continue
            }

            aggregates.append(
                makeAggregate(
                    dayStart: interval.start,
                    dayEnd: interval.end,
                    events: [],
                    generatedAt: interval.start
                )
            )
            existingDayIDs.insert(dayID)
        }

        return aggregates.sorted { $0.bucketStartAt < $1.bucketStartAt }
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
        var workItems = [String: PrivateUsageWorkItemAggregate]()
        let bucketDay = Self.localDayID(for: dayStart, timeZone: timeZone)

        for event in events {
            totals.add(event)
            add(event, to: &toolTotals, key: event.aiTool.rawValue)
            add(event, to: &modelTotals, key: event.model)
            add(event, to: &taskTypeTotals, key: event.taskType.rawValue)
            add(event, to: &stageTotals, key: event.stage.rawValue)
            add(event, bucketDay: bucketDay, to: &workItems)
            workflowUsageTotals.add(event)
            sourceTotals["system", default: 0] += event.tokenBreakdown.system
            sourceTotals["user", default: 0] += event.tokenBreakdown.user
            sourceTotals["history", default: 0] += event.tokenBreakdown.history
            sourceTotals["repo_context", default: 0] += event.tokenBreakdown.repoContext
            sourceTotals["tool_output", default: 0] += event.tokenBreakdown.toolOutput
            sourceTotals["generated_output", default: 0] += event.tokenBreakdown.generatedOutput
            sourceTotals["unknown", default: 0] += event.tokenBreakdown.unknown
        }

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
            workflowUsageTotals: workflowUsageTotals,
            workItems: workItems.values.sorted { lhs, rhs in
                lhs.totals.totalTokens == rhs.totals.totalTokens
                    ? lhs.id < rhs.id
                    : lhs.totals.totalTokens > rhs.totals.totalTokens
            }
        )
    }
}

private extension PrivateUsageDailyBucketBuilder {
    func add(
        _ event: TokenUsageEvent,
        to totals: inout [String: PrivateUsageTokenTotals],
        key: String
    ) {
        var current = totals[key] ?? .zero
        current.add(event)
        totals[key] = current
    }

    func add(
        _ event: TokenUsageEvent,
        bucketDay: String,
        to workItems: inout [String: PrivateUsageWorkItemAggregate]
    ) {
        let id = Self.workItemID(for: event, bucketDay: bucketDay)
        var current = workItems[id] ?? PrivateUsageWorkItemAggregate(
            id: id,
            aiTool: event.aiTool.rawValue,
            taskType: event.taskType.rawValue,
            stage: event.stage.rawValue,
            model: Self.modelKey(event.model),
            totals: .zero,
            firstEventAt: event.createdAt,
            lastEventAt: event.createdAt
        )
        current.add(event)
        workItems[id] = current
    }

    static func workItemID(for event: TokenUsageEvent, bucketDay: String) -> String {
        [
            "work",
            event.aiTool.rawValue,
            event.taskType.rawValue,
            event.stage.rawValue,
            modelKey(event.model),
            bucketDay
        ].map(safeIDPart).joined(separator: "__")
    }

    static func modelKey(_ model: String) -> String {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty ||
            normalized == "unknown" ||
            normalized == "unknown_model" ||
            normalized == "model_unknown" ||
            normalized == "unavailable"
        {
            return "model_unavailable"
        }
        return model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func safeIDPart(_ value: String) -> String {
        let normalized = value.lowercased()
        let scalars = normalized.unicodeScalars.map { scalar -> Character in
            if (48...57).contains(scalar.value) || (97...122).contains(scalar.value) {
                return Character(scalar)
            }
            return "_"
        }
        let collapsed = String(scalars)
            .split(separator: "_", omittingEmptySubsequences: true)
            .joined(separator: "_")
        return collapsed.isEmpty ? "unknown" : collapsed
    }
}
