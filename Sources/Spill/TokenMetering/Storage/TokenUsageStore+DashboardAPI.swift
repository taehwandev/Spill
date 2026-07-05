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
        dashboardToolsOnly: Bool = true
    ) -> TokenUsageMenuBarTotals? {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return nil
            }
            defer { sqlite3_close(database) }

            guard
                let daily = loadDashboardCountAndTotalIfAvailable(
                    startingAt: startDate,
                    endingBefore: endDate,
                    dashboardToolsOnly: dashboardToolsOnly,
                    database: database
                ),
                let allTime = loadDashboardCountAndTotalIfAvailable(
                    dashboardToolsOnly: dashboardToolsOnly,
                    database: database
                )
            else {
                return nil
            }

            return TokenUsageMenuBarTotals(
                dailyTokens: daily.totalTokens,
                allTimeTokens: allTime.totalTokens
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
