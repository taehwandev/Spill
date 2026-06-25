import Foundation

enum TokenUsageHistoryImportFailureStage: String, Equatable, Sendable {
    case prepare
    case locateImporter
    case locateRuntime
    case sourceDiscovery
    case process
    case parseSummary
    case write
    case unknown
}
