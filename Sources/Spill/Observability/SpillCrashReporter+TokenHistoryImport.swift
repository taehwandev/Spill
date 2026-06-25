import Foundation
import Sentry

extension SpillCrashReporter {
    static func captureTokenHistoryImportFailure(
        tool: TokenUsageHistoryImportTool,
        mode: TokenUsageHistoryImportMode,
        result: TokenUsageHistoryToolResult
    ) {
        guard isReportingEnabled else {
            return
        }

        let reason = result.failureReason?.rawValue ?? "unknown_failed"
        let stage = result.failureStage?.rawValue ?? "unknown"
        SentrySDK.capture(message: "spill.token_history_import_failed") { scope in
            scope.setFingerprint(["spill.token_history_import_failed", tool.rawValue, stage, reason])
            scope.setTag(value: "token_history_import_failed", key: "spill_failure")
            scope.setTag(value: tool.rawValue, key: "history_import_tool")
            scope.setTag(value: mode.rawValue, key: "history_import_mode")
            scope.setTag(value: result.state.rawValue, key: "history_import_state")
            scope.setTag(value: reason, key: "history_import_reason")
            scope.setTag(value: stage, key: "history_import_stage")
            scope.setTag(value: result.timedOut ? "true" : "false", key: "history_import_timed_out")
            scope.setTag(value: bucketedExitCode(result.exitCode), key: "history_import_exit_code")
            scope.setTag(value: bucketedDuration(result.durationSeconds), key: "history_import_duration")
            scope.setTag(value: "\(TokenUsageHistoryImportCoordinator.importerVersion)", key: "history_importer_version")
            scope.setTag(value: "1", key: "usage_event_schema")
            scope.setTag(value: bucketedCount(result.scannedSources), key: "history_import_scanned_sources")
            scope.setTag(value: bucketedCount(result.importedEvents), key: "history_import_imported_events")
            scope.setTag(value: bucketedCount(result.skippedDuplicates), key: "history_import_skipped_duplicates")
            scope.setTag(value: bucketedCount(result.unsupportedRecords), key: "history_import_unsupported_records")
        }
    }

    private static func bucketedCount(_ value: Int) -> String {
        switch value {
        case ..<0:
            return "invalid"
        case 0:
            return "0"
        case 1:
            return "1"
        case 2...10:
            return "2_10"
        case 11...100:
            return "11_100"
        case 101...1_000:
            return "101_1000"
        case 1_001...10_000:
            return "1001_10000"
        default:
            return "10000_plus"
        }
    }

    private static func bucketedExitCode(_ value: Int32?) -> String {
        guard let value else {
            return "none"
        }
        switch value {
        case 0:
            return "0"
        case -1:
            return "launch_failed"
        case 1:
            return "1"
        case 2:
            return "2"
        case 126:
            return "126"
        case 127:
            return "127"
        case 128...255:
            return "128_255"
        default:
            return "other"
        }
    }

    private static func bucketedDuration(_ value: TimeInterval?) -> String {
        guard let value else {
            return "none"
        }
        switch value {
        case ..<0:
            return "invalid"
        case 0..<1:
            return "lt_1s"
        case 1..<5:
            return "1_5s"
        case 5..<30:
            return "5_30s"
        case 30..<120:
            return "30_120s"
        case 120..<300:
            return "120_300s"
        default:
            return "300s_plus"
        }
    }
}
