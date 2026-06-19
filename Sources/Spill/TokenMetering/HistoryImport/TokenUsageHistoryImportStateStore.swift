import Foundation

final class TokenUsageHistoryImportStateStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "app.spill.token-history-import"
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    func hasCompletedFirstImport(for tool: TokenUsageHistoryImportTool) -> Bool {
        defaults.object(forKey: firstCompletedKey(for: tool)) != nil
    }

    func lastSuccessfulImportAt(for tool: TokenUsageHistoryImportTool) -> Date? {
        defaults.object(forKey: lastSuccessKey(for: tool)) as? Date
    }

    func lastRun(for tool: TokenUsageHistoryImportTool) -> TokenUsageHistoryImportLastRunSnapshot? {
        guard let data = defaults.data(forKey: lastRunKey(for: tool)) else {
            return nil
        }
        return try? JSONDecoder().decode(TokenUsageHistoryImportLastRunSnapshot.self, from: data)
    }

    func markSuccessfulImport(
        for tool: TokenUsageHistoryImportTool,
        mode: TokenUsageHistoryImportMode,
        at date: Date
    ) {
        defaults.set(date, forKey: lastSuccessKey(for: tool))
        if mode == .firstImport {
            defaults.set(date, forKey: firstCompletedKey(for: tool))
        }
    }

    func recordLastRun(
        for tool: TokenUsageHistoryImportTool,
        result: TokenUsageHistoryToolResult,
        at date: Date
    ) {
        let snapshot = TokenUsageHistoryImportLastRunSnapshot(
            finishedAt: date,
            state: result.state,
            scannedSources: result.scannedSources,
            importedEvents: result.importedEvents,
            skippedDuplicates: result.skippedDuplicates,
            unsupportedRecords: result.unsupportedRecords,
            message: result.message
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: lastRunKey(for: tool))
        }
    }

    func resetAllImportState() {
        resetImportState(for: TokenUsageHistoryImportTool.allCases)
    }

    func resetImportState(for tools: [TokenUsageHistoryImportTool]) {
        for tool in tools {
            defaults.removeObject(forKey: firstCompletedKey(for: tool))
            defaults.removeObject(forKey: lastSuccessKey(for: tool))
        }
    }

    private func firstCompletedKey(for tool: TokenUsageHistoryImportTool) -> String {
        "\(keyPrefix).v\(TokenUsageHistoryImportCoordinator.importerVersion).\(tool.rawValue).first_import_completed_at"
    }

    private func lastSuccessKey(for tool: TokenUsageHistoryImportTool) -> String {
        "\(keyPrefix).v\(TokenUsageHistoryImportCoordinator.importerVersion).\(tool.rawValue).last_successful_import_at"
    }

    private func lastRunKey(for tool: TokenUsageHistoryImportTool) -> String {
        "\(keyPrefix).v\(TokenUsageHistoryImportCoordinator.importerVersion).\(tool.rawValue).last_run"
    }
}
