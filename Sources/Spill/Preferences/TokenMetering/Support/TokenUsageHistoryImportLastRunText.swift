import Foundation

enum TokenUsageHistoryImportLastRunText {
    static func text(
        for lastRun: TokenUsageHistoryImportLastRunSnapshot?,
        language: TokenMeteringLanguage
    ) -> String? {
        guard let lastRun else {
            return nil
        }
        let metrics = [
            "\(t(.historyImportMetricSources, language: language)) \(TokenUsageDashboardSnapshot.formatCount(lastRun.scannedSources))",
            "\(t(.historyImportMetricNew, language: language)) \(TokenUsageDashboardSnapshot.formatCount(lastRun.importedEvents))",
            "\(t(.historyImportMetricDuplicates, language: language)) \(TokenUsageDashboardSnapshot.formatCount(lastRun.skippedDuplicates))",
            "\(t(.historyImportMetricUnsupported, language: language)) \(TokenUsageDashboardSnapshot.formatCount(lastRun.unsupportedRecords))"
        ]
        return [
            "\(t(.historyImportLastSync, language: language)) \(formatDate(lastRun.finishedAt, language: language))",
            stateText(lastRun.state, language: language),
            metrics.joined(separator: " / ")
        ].joined(separator: " · ")
    }

    private static func stateText(_ state: TokenUsageHistoryImportToolState, language: TokenMeteringLanguage) -> String {
        switch state {
        case .pending:
            return t(.historyImportStateWaiting, language: language)
        case .running:
            return t(.historyImportStateScanning, language: language)
        case .completed:
            return t(.historyImportStateDone, language: language)
        case .unavailable:
            return t(.historyImportStateNoSource, language: language)
        case .failed:
            return t(.historyImportStateFailed, language: language)
        case .cancelled:
            return t(.historyImportStateCancelled, language: language)
        }
    }

    private static func formatDate(_ date: Date, language: TokenMeteringLanguage) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func t(_ key: TokenMeteringTextKey, language: TokenMeteringLanguage) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
