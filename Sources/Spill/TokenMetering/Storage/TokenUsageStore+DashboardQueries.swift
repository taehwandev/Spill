import Foundation
import SQLite3

extension TokenUsageStore {
    static let dashboardFreshTokenSQL = "output_tokens + COALESCE(accounting_uncached_input_tokens, 0)"

    func loadDashboardSummary(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer
    ) -> TokenUsageDashboardSummary {
        guard let totals = loadDashboardCountAndTotalIfAvailable(
            startingAt: startDate,
            endingBefore: endDate,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database
        ) else {
            return .empty
        }
        return TokenUsageDashboardSummary(
            eventCount: totals.eventCount,
            totalTokens: totals.totalTokens,
            exactFreshTotalTokens: totals.exactFreshTotalTokens,
            toolTotals: loadGroupedTokenTotals(
                column: "ai_tool",
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            ),
            taskTotals: loadGroupedTokenTotals(
                column: "task_type",
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            ),
            sourceTotals: loadSourceTokenTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            )
        )
    }

    func loadDashboardDateBounds(
        selectedTool: TokenUsageAITool?,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> TokenUsageDashboardDateBounds {
        var conditions = [String]()
        if selectedTool != nil {
            conditions.append("ai_tool = ?")
        } else if let toolCondition = Self.dashboardToolCondition(
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        ) {
            conditions.append(toolCondition)
        }

        var sql = """
        SELECT MIN(created_at), MAX(created_at)
        FROM token_usage_events
        """
        if !conditions.isEmpty {
            sql += "\nWHERE \(conditions.joined(separator: " AND "))"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return .empty
        }
        defer { sqlite3_finalize(statement) }

        if let selectedTool {
            sqlite3_bind_text(statement, 1, selectedTool.rawValue, -1, SQLITE_TRANSIENT)
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            failureObserver?.markFailure()
            return .empty
        }

        let earliest = Self.columnString(statement, 0)
            .flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:))
        let latest = Self.columnString(statement, 1)
            .flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:))
        return TokenUsageDashboardDateBounds(earliest: earliest, latest: latest)
    }

    func loadDashboardCountAndTotal(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> (eventCount: Int, totalTokens: Int, exactFreshTotalTokens: Int) {
        loadDashboardCountAndTotalIfAvailable(
            startingAt: startDate,
            endingBefore: endDate,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        ) ?? (0, 0, 0)
    }

    /// Returns nil for two different reasons the caller must keep distinct: a prepare/step
    /// failure (marks `failureObserver`, so a batch caller can fail closed) versus this query
    /// simply not being asked for -- it never returns nil for a valid empty range, since an empty
    /// range still steps one COUNT/SUM row of zeros. Only genuine statement failure marks the
    /// observer here; comparisonTokenTotal's own eventCount == 0 -> nil mapping stays a legitimate
    /// no-data result and must not be treated as a failure.
    func loadDashboardCountAndTotalIfAvailable(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> (eventCount: Int, totalTokens: Int, exactFreshTotalTokens: Int)? {
        let sql = """
        SELECT COUNT(*),
               COALESCE(SUM(total_tokens), 0),
               COALESCE(SUM(\(Self.dashboardFreshTokenSQL)), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return nil
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            failureObserver?.markFailure()
            return nil
        }

        return (
            eventCount: Int(sqlite3_column_int64(statement, 0)),
            totalTokens: Int(sqlite3_column_int64(statement, 1)),
            exactFreshTotalTokens: Int(sqlite3_column_int64(statement, 2))
        )
    }

    struct DashboardFocusedTotals {
        let eventCount: Int
        let totalTokens: Int
        let exactFreshTotalTokens: Int
        let inputTokens: Int
        let outputTokens: Int
        let assistedEventCount: Int
        let assistedTotalTokens: Int
    }

    /// One round trip for every scalar total TokenMeteringPresentationModel.init currently
    /// derives from focusedEvents.reduce(...): the KPI row (event/input/output totals) and
    /// workflowUsage's assisted-work ratio (TokenUsageWorkflowAssistance.isAssisted mirrored as
    /// `task_type != 'uncategorized' OR stage != 'summarize'`). assistedTotalTokens intentionally
    /// sums total_tokens only (includeCache), matching the existing Swift reducer, which is not
    /// inputScope-aware here either.
    func loadDashboardFocusedTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> DashboardFocusedTotals {
        let assistedCondition = "(task_type != 'uncategorized' OR stage != 'summarize')"
        let sql = """
        SELECT COUNT(*),
               COALESCE(SUM(total_tokens), 0),
               COALESCE(SUM(\(Self.dashboardFreshTokenSQL)), 0),
               COALESCE(SUM(input_tokens), 0),
               COALESCE(SUM(output_tokens), 0),
               COUNT(CASE WHEN \(assistedCondition) THEN 1 END),
               COALESCE(SUM(CASE WHEN \(assistedCondition) THEN total_tokens ELSE 0 END), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return DashboardFocusedTotals(
                eventCount: 0, totalTokens: 0, exactFreshTotalTokens: 0,
                inputTokens: 0, outputTokens: 0, assistedEventCount: 0, assistedTotalTokens: 0
            )
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            failureObserver?.markFailure()
            return DashboardFocusedTotals(
                eventCount: 0, totalTokens: 0, exactFreshTotalTokens: 0,
                inputTokens: 0, outputTokens: 0, assistedEventCount: 0, assistedTotalTokens: 0
            )
        }

        return DashboardFocusedTotals(
            eventCount: Int(sqlite3_column_int64(statement, 0)),
            totalTokens: Int(sqlite3_column_int64(statement, 1)),
            exactFreshTotalTokens: Int(sqlite3_column_int64(statement, 2)),
            inputTokens: Int(sqlite3_column_int64(statement, 3)),
            outputTokens: Int(sqlite3_column_int64(statement, 4)),
            assistedEventCount: Int(sqlite3_column_int64(statement, 5)),
            assistedTotalTokens: Int(sqlite3_column_int64(statement, 6))
        )
    }

    /// Mirrors TokenUsageDashboardSnapshot.lastUpdatedDates: MAX(created_at) per tool over the
    /// same dashboardToolsOnly/visibleTools-scoped rows, plus an overall max across all of them.
    func loadLastUpdatedByTool(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [TokenUsageAITool: Date] {
        let sql = """
        SELECT ai_tool, MAX(created_at)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        GROUP BY ai_tool
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        var result = [TokenUsageAITool: Date]()
        var stepResult = sqlite3_step(statement)
        while stepResult == SQLITE_ROW {
            defer { stepResult = sqlite3_step(statement) }
            guard let aiToolRaw = Self.columnString(statement, 0),
                  let maxCreatedAtText = Self.columnString(statement, 1),
                  let maxCreatedAt = ISO8601DateFormatter.parseTokenUsageDate(from: maxCreatedAtText)
            else {
                continue
            }

            let aiTool: TokenUsageAITool
            switch aiToolRaw {
            case "agy":
                aiTool = .antigravity
            case "ollama":
                aiTool = .unknown
            default:
                aiTool = TokenUsageAITool(rawValue: aiToolRaw) ?? .unknown
            }
            result[aiTool] = maxCreatedAt
        }
        if stepResult != SQLITE_DONE {
            failureObserver?.markFailure()
        }
        return result
    }

    func loadMenuBarTokenTotalIfAvailable(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        inputScope: TokenUsageInputScope,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer
    ) -> Int? {
        let tokenExpression = switch inputScope {
        case .includeCache:
            "total_tokens"
        case .freshOnly:
            Self.dashboardFreshTokenSQL
        }
        let sql = """
        SELECT COALESCE(SUM(\(tokenExpression)), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return Int(sqlite3_column_int64(statement, 0))
    }

    func loadGroupedTokenTotals(
        column: String,
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer
    ) -> [String: Int] {
        let sql = """
        SELECT \(column), COALESCE(SUM(total_tokens), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        GROUP BY \(column)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        var totals = [String: Int]()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let keyText = sqlite3_column_text(statement, 0) else {
                continue
            }
            let key = String(cString: keyText)
            guard !key.isEmpty else {
                continue
            }
            totals[key] = Int(sqlite3_column_int64(statement, 1))
        }
        return totals
    }

    /// Grouped by project_id, unlike the day-bucket queries this needs no calendar-aware
    /// bucketing (project_id is a plain string key), so a real SQL GROUP BY is safe here.
    func loadGroupedProjectTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: (eventCount: Int, totals: TokenUsageInputScopeTotals)] {
        let sql = """
        SELECT project_id,
               COUNT(*),
               COALESCE(SUM(total_tokens), 0),
               COALESCE(SUM(\(Self.dashboardFreshTokenSQL)), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        GROUP BY project_id
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        var totals = [String: (eventCount: Int, totals: TokenUsageInputScopeTotals)]()
        var stepResult = sqlite3_step(statement)
        while stepResult == SQLITE_ROW {
            defer { stepResult = sqlite3_step(statement) }
            guard let keyText = sqlite3_column_text(statement, 0) else {
                continue
            }
            let key = String(cString: keyText)
            guard !key.isEmpty else {
                continue
            }
            totals[key] = (
                eventCount: Int(sqlite3_column_int64(statement, 1)),
                totals: TokenUsageInputScopeTotals(
                    includeCache: Int(sqlite3_column_int64(statement, 2)),
                    freshOnly: Int(sqlite3_column_int64(statement, 3))
                )
            )
        }
        if stepResult != SQLITE_DONE {
            failureObserver?.markFailure()
        }
        return totals
    }

    /// Fresh-scope-aware sibling of loadGroupedTokenTotals(column:), for callers (toolRows,
    /// taskRows, stageRows) whose Swift-side reducer is inputScope-aware and therefore can't use
    /// the includeCache-only original.
    func loadGroupedInputScopeTotals(
        column: String,
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: TokenUsageInputScopeTotals] {
        let sql = """
        SELECT \(column),
               COALESCE(SUM(total_tokens), 0),
               COALESCE(SUM(\(Self.dashboardFreshTokenSQL)), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        GROUP BY \(column)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        var totals = [String: TokenUsageInputScopeTotals]()
        var stepResult = sqlite3_step(statement)
        while stepResult == SQLITE_ROW {
            defer { stepResult = sqlite3_step(statement) }
            guard let keyText = sqlite3_column_text(statement, 0) else {
                continue
            }
            let key = String(cString: keyText)
            guard !key.isEmpty else {
                continue
            }
            totals[key] = TokenUsageInputScopeTotals(
                includeCache: Int(sqlite3_column_int64(statement, 1)),
                freshOnly: Int(sqlite3_column_int64(statement, 2))
            )
        }
        if stepResult != SQLITE_DONE {
            failureObserver?.markFailure()
        }
        return totals
    }

    /// Fresh-scope-aware sibling of loadGroupedModelTotals; see that function's doc comment for
    /// the modelKey-normalization and TRIM-character-set caveats, both identical here.
    func loadGroupedModelInputScopeTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: TokenUsageInputScopeTotals] {
        let trimExpr = "TRIM(model, ' ' || char(9) || char(10) || char(13))"
        let keyExpr = """
        CASE
            WHEN \(trimExpr) = ''
                OR LOWER(\(trimExpr)) IN ('unknown', 'unknown_model', 'model_unknown', 'unavailable')
            THEN 'model_unavailable'
            ELSE \(trimExpr)
        END
        """
        let sql = """
        SELECT \(keyExpr),
               COALESCE(SUM(total_tokens), 0),
               COALESCE(SUM(\(Self.dashboardFreshTokenSQL)), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        GROUP BY 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        var totals = [String: TokenUsageInputScopeTotals]()
        var stepResult = sqlite3_step(statement)
        while stepResult == SQLITE_ROW {
            defer { stepResult = sqlite3_step(statement) }
            guard let keyText = sqlite3_column_text(statement, 0) else {
                continue
            }
            let key = String(cString: keyText)
            guard !key.isEmpty else {
                continue
            }
            totals[key] = TokenUsageInputScopeTotals(
                includeCache: Int(sqlite3_column_int64(statement, 1)),
                freshOnly: Int(sqlite3_column_int64(statement, 2))
            )
        }
        if stepResult != SQLITE_DONE {
            failureObserver?.markFailure()
        }
        return totals
    }

    /// Mirrors TokenUsageDashboardSnapshot.modelKey in SQL: collapses empty/whitespace-only and
    /// known "unknown" spellings into "model_unavailable", otherwise groups by the trimmed model
    /// string as-is (case preserved). SQLite's two-arg TRIM only strips the listed characters
    /// (space/tab/CR/LF here), a narrower set than Swift's .whitespacesAndNewlines CharacterSet
    /// (which also covers some Unicode spaces) -- acceptable since model name strings from CLI
    /// tools don't contain those in practice, but a real divergence if one ever did.
    func loadGroupedModelTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer
    ) -> [String: Int] {
        let trimExpr = "TRIM(model, ' ' || char(9) || char(10) || char(13))"
        let keyExpr = """
        CASE
            WHEN \(trimExpr) = ''
                OR LOWER(\(trimExpr)) IN ('unknown', 'unknown_model', 'model_unknown', 'unavailable')
            THEN 'model_unavailable'
            ELSE \(trimExpr)
        END
        """
        let sql = """
        SELECT \(keyExpr), COALESCE(SUM(total_tokens), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        GROUP BY 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        var totals = [String: Int]()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let keyText = sqlite3_column_text(statement, 0) else {
                continue
            }
            let key = String(cString: keyText)
            guard !key.isEmpty else {
                continue
            }
            totals[key] = Int(sqlite3_column_int64(statement, 1))
        }
        return totals
    }

    func loadSourceTokenTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: Int] {
        let sql = """
        SELECT
            COALESCE(SUM(source_system), 0),
            COALESCE(SUM(source_user), 0),
            COALESCE(SUM(source_history), 0),
            COALESCE(SUM(source_repo_context), 0),
            COALESCE(SUM(source_tool_output), 0),
            COALESCE(SUM(source_generated_output), 0),
            COALESCE(SUM(source_unknown), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            failureObserver?.markFailure()
            return [:]
        }

        return [
            "system": Int(sqlite3_column_int64(statement, 0)),
            "user": Int(sqlite3_column_int64(statement, 1)),
            "history": Int(sqlite3_column_int64(statement, 2)),
            "repo_context": Int(sqlite3_column_int64(statement, 3)),
            "tool_output": Int(sqlite3_column_int64(statement, 4)),
            "generated_output": Int(sqlite3_column_int64(statement, 5)),
            "unknown": Int(sqlite3_column_int64(statement, 6))
        ]
    }

    /// Mirrors TokenUsageDashboardSnapshot.inputAccounting's per-event logic in SQL: a row's
    /// input tokens only split into uncached/cache-creation/cache-read when all four accounting
    /// columns are present (matching TokenUsageEvent's tokenAccounting != nil check); otherwise
    /// the row's full input_tokens count as unclassified, same as an event with no tokenAccounting.
    func loadInputAccountingTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: Int] {
        let hasAccounting = """
        accounting_uncached_input_tokens IS NOT NULL \
        AND accounting_cache_creation_input_tokens IS NOT NULL \
        AND accounting_cache_read_input_tokens IS NOT NULL \
        AND accounting_reasoning_output_tokens IS NOT NULL
        """
        let baseWhere = Self.dashboardWhereClause(
            startingAt: startDate,
            endingBefore: endDate,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        )
        let whereClause = baseWhere.isEmpty
            ? "WHERE input_tokens > 0"
            : "\(baseWhere) AND input_tokens > 0"
        let sql = """
        SELECT
            COALESCE(SUM(CASE WHEN \(hasAccounting) THEN accounting_uncached_input_tokens ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN \(hasAccounting) THEN accounting_cache_creation_input_tokens ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN \(hasAccounting) THEN accounting_cache_read_input_tokens ELSE 0 END), 0),
            COALESCE(SUM(
                CASE WHEN \(hasAccounting)
                     THEN MAX(0, input_tokens - (
                         accounting_uncached_input_tokens
                         + accounting_cache_creation_input_tokens
                         + accounting_cache_read_input_tokens
                     ))
                     ELSE input_tokens
                END
            ), 0)
        FROM token_usage_events
        \(whereClause)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            failureObserver?.markFailure()
            return [:]
        }

        return [
            "uncached_input": Int(sqlite3_column_int64(statement, 0)),
            "cache_creation_input": Int(sqlite3_column_int64(statement, 1)),
            "cache_read_input": Int(sqlite3_column_int64(statement, 2)),
            "unclassified_input": Int(sqlite3_column_int64(statement, 3))
        ]
    }

}
