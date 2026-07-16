import Foundation
import SQLite3

struct TokenUsageMenuBarTotals: Equatable, Sendable {
    let dailyTokens: Int
    let allTimeTokens: Int
}

extension TokenUsageStore {
    func menuBarTokenTotals(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        inputScope: TokenUsageInputScope = .includeCache,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> TokenUsageMenuBarTotals? {
        lock.withLock { () -> TokenUsageMenuBarTotals? in
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return nil
            }
            defer { sqlite3_close(database) }

            guard
                let dailyTokens = loadMenuBarTokenTotalIfAvailable(
                    startingAt: startDate,
                    endingBefore: endDate,
                    inputScope: inputScope,
                    dashboardToolsOnly: dashboardToolsOnly,
                    visibleTools: visibleTools,
                    database: database
                ),
                let allTimeTotals = loadDashboardCountAndTotalIfAvailable(
                    dashboardToolsOnly: dashboardToolsOnly,
                    visibleTools: visibleTools,
                    database: database
                )
            else {
                return nil
            }

            return TokenUsageMenuBarTotals(
                dailyTokens: dailyTokens,
                allTimeTokens: TokenUsageInputScopeTotals(
                    includeCache: allTimeTotals.totalTokens,
                    freshOnly: allTimeTotals.exactFreshTotalTokens
                ).total(for: inputScope)
            )
        }
    }

    func totalTokens(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        dashboardToolsOnly: Bool = true
    ) -> Int {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return 0
            }
            defer { sqlite3_close(database) }

            return loadTotalTokens(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            )
        }
    }

    func allTimeTotalTokens(dashboardToolsOnly: Bool = true) -> Int {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return 0
            }
            defer { sqlite3_close(database) }

            return loadDashboardCountAndTotal(
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            ).totalTokens
        }
    }

    func allPeriodTotalTokens(
        now: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> [TokenUsageDashboardPeriod: Int] {
        allPeriodInputScopeTotals(
            now: now,
            calendar: calendar,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        )
        .mapValues(\.includeCache)
    }

    func allPeriodInputScopeTotals(
        now: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals] {
        withDatabaseConnection(database, default: [:]) { database in
            loadAllPeriodTotalTokens(
                now: now,
                calendar: calendar,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
    }

    func dashboardSummary(dashboardToolsOnly: Bool = true) -> TokenUsageDashboardSummary {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return .empty
            }
            defer { sqlite3_close(database) }

            return loadDashboardSummary(
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            )
        }
    }

    func dashboardSummary(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> TokenUsageDashboardSummary {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return .empty
            }
            defer { sqlite3_close(database) }

            return loadDashboardSummary(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            )
        }
    }

    /// Returns nil when the database cannot produce even its primary count/total query.
    /// Callers that already have a rendered summary can preserve it instead of replacing it
    /// with the indistinguishable empty snapshot used for a valid zero-event range.
    func dashboardSummaryIfAvailable(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> TokenUsageDashboardSummary? {
        // Route through withDatabaseConnection like the other range-scoped dashboard readers so a
        // caller (e.g. the dashboard SQL snapshot build) can pass its own already-open connection
        // and read the panel summary inside the same transaction as the rest of the snapshot,
        // rather than on a second connection that could observe a different WAL commit point.
        withDatabaseConnection(database, default: nil) { database -> TokenUsageDashboardSummary? in
            guard loadDashboardCountAndTotalIfAvailable(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            ) != nil else {
                return nil
            }

            return loadDashboardSummary(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            )
        }
    }

    /// Reuses loadDashboardCountAndTotalIfAvailable rather than a SUM-only query so an empty
    /// range (eventCount == 0) can return nil -- matching the existing comparisonTotalTokens
    /// Swift reducer's `compEvents.isEmpty ? nil : ...`, which COALESCE(SUM(...), 0) alone can't
    /// distinguish from a range whose events happen to sum to zero.
    func comparisonTokenTotal(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        inputScope: TokenUsageInputScope = .includeCache,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> Int? {
        withDatabaseConnection(database, default: nil) { database -> Int? in
            guard let totals = loadDashboardCountAndTotalIfAvailable(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            ), totals.eventCount > 0
            else {
                return nil
            }

            switch inputScope {
            case .includeCache:
                return totals.totalTokens
            case .freshOnly:
                return totals.exactFreshTotalTokens
            }
        }
    }

    func inputAccountingTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: Int] {
        withDatabaseConnection(database, default: [:]) { database in
            loadInputAccountingTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
    }

    func dashboardFocusedTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> DashboardFocusedTotals {
        withDatabaseConnection(
            database,
            default: DashboardFocusedTotals(
                eventCount: 0, totalTokens: 0, exactFreshTotalTokens: 0,
                inputTokens: 0, outputTokens: 0, assistedEventCount: 0, assistedTotalTokens: 0
            )
        ) { database in
            loadDashboardFocusedTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
    }

    func lastUpdatedByTool(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [TokenUsageAITool: Date] {
        withDatabaseConnection(database, default: [:]) { database in
            loadLastUpdatedByTool(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
    }

    func groupedModelTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> [String: Int] {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return [:]
            }
            defer { sqlite3_close(database) }

            return loadGroupedModelTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            )
        }
    }

    func groupedInputScopeTotalsByTool(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [TokenUsageAITool: TokenUsageInputScopeTotals] {
        let raw: [String: TokenUsageInputScopeTotals] = withDatabaseConnection(database, default: [:]) { database in
            loadGroupedInputScopeTotals(
                column: "ai_tool",
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
        var totals = [TokenUsageAITool: TokenUsageInputScopeTotals]()
        for (key, value) in raw {
            let tool: TokenUsageAITool = key == "agy" ? .antigravity : (TokenUsageAITool(rawValue: key) ?? .unknown)
            let existing = totals[tool] ?? .zero
            totals[tool] = TokenUsageInputScopeTotals(
                includeCache: existing.includeCache + value.includeCache,
                freshOnly: existing.freshOnly + value.freshOnly
            )
        }
        return totals
    }

    func groupedTaskTypeInputScopeTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: TokenUsageInputScopeTotals] {
        withDatabaseConnection(database, default: [:]) { database in
            loadGroupedInputScopeTotals(
                column: "task_type",
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
    }

    func groupedStageInputScopeTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: TokenUsageInputScopeTotals] {
        withDatabaseConnection(database, default: [:]) { database in
            loadGroupedInputScopeTotals(
                column: "stage",
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
    }

    func groupedModelInputScopeTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: TokenUsageInputScopeTotals] {
        withDatabaseConnection(database, default: [:]) { database in
            loadGroupedModelInputScopeTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
    }

    // loadGroupedTokenTotals sums total_tokens only (includeCache), matching every other
    // caller of it today (dashboardSummary's toolTotals/taskTotals). The Swift-side
    // taskRows/stageRows reducer these are meant to eventually replace is inputScope-aware;
    // wiring that in needs a fresh-token variant of the grouped-totals SQL, not added here.
    func groupedTaskTypeTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> [String: Int] {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return [:]
            }
            defer { sqlite3_close(database) }

            return loadGroupedTokenTotals(
                column: "task_type",
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            )
        }
    }

    func groupedStageTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> [String: Int] {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return [:]
            }
            defer { sqlite3_close(database) }

            return loadGroupedTokenTotals(
                column: "stage",
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            )
        }
    }

    func sourceTokenTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: Int] {
        withDatabaseConnection(database, default: [:]) { database in
            loadSourceTokenTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
    }

    func groupedProjectTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: (eventCount: Int, totals: TokenUsageInputScopeTotals)] {
        withDatabaseConnection(database, default: [:]) { database in
            loadGroupedProjectTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
    }

    func dashboardDateBounds(
        selectedTool: TokenUsageAITool? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> TokenUsageDashboardDateBounds {
        withDatabaseConnection(database, default: .empty) { database in
            loadDashboardDateBounds(
                selectedTool: selectedTool,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
    }

    func dashboardDayTokenTotals(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> [String: Int] {
        dashboardDayInputScopeTotals(
            startingAt: startDate,
            endingBefore: endDate,
            calendar: calendar,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        )
        .mapValues(\.includeCache)
    }

    func dashboardDayInputScopeTotals(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: TokenUsageInputScopeTotals] {
        withDatabaseConnection(database, default: [:]) { database in
            loadDashboardDayTokenTotals(
                startingAt: startDate,
                endingBefore: endDate,
                calendar: calendar,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }
    }
}
