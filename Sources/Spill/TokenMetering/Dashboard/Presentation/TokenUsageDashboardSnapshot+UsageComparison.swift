extension TokenUsageDashboardSnapshot {
    /// Uses the applied snapshot scope for the current total. The comparison
    /// total was already projected to that scope when this snapshot was built.
    func usageComparison(for scope: TokenUsageInputScope) -> (delta: Int, percentage: Double)? {
        guard let comparisonTotalTokens, comparisonTotalTokens > 0 else {
            return nil
        }

        let delta = usageInputScopeTotals.total(for: scope) - comparisonTotalTokens
        return (delta, Double(delta) / Double(comparisonTotalTokens) * 100)
    }
}
