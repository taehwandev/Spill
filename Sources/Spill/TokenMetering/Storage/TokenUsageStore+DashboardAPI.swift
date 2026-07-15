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
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals] {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return [:]
            }
            defer { sqlite3_close(database) }
            return loadAllPeriodTotalTokens(
                now: now,
                calendar: calendar,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
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

    /// Reuses loadDashboardCountAndTotalIfAvailable rather than a SUM-only query so an empty
    /// range (eventCount == 0) can return nil -- matching the existing comparisonTotalTokens
    /// Swift reducer's `compEvents.isEmpty ? nil : ...`, which COALESCE(SUM(...), 0) alone can't
    /// distinguish from a range whose events happen to sum to zero.
    func comparisonTokenTotal(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        inputScope: TokenUsageInputScope = .includeCache,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> Int? {
        lock.withLock { () -> Int? in
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return nil
            }
            defer { sqlite3_close(database) }

            guard let totals = loadDashboardCountAndTotalIfAvailable(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
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

            return loadInputAccountingTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
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

    func groupedProjectTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> [String: (eventCount: Int, totals: TokenUsageInputScopeTotals)] {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return [:]
            }
            defer { sqlite3_close(database) }

            return loadGroupedProjectTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            )
        }
    }

    func dashboardDateBounds(
        selectedTool: TokenUsageAITool? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> TokenUsageDashboardDateBounds {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return .empty
            }
            defer { sqlite3_close(database) }

            return loadDashboardDateBounds(
                selectedTool: selectedTool,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
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
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> [String: TokenUsageInputScopeTotals] {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return [:]
            }
            defer { sqlite3_close(database) }

            return loadDashboardDayTokenTotals(
                startingAt: startDate,
                endingBefore: endDate,
                calendar: calendar,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            )
        }
    }
}
