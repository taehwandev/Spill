import Foundation

final class TokenUsageAntigravityImporter {
    let conversationsDirectory: URL
    let labelTimelineURL: URL
    let diagnosticsURL: URL?
    let stateURL: URL?
    let fileManager: FileManager
    let forceTemporaryCopyFallback: Bool

    init(
        conversationsDirectory: URL = TokenUsageAntigravityImporter.defaultConversationsDirectory(),
        labelTimelineURL: URL = TokenUsageAntigravityImporter.defaultLabelTimelineURL(),
        diagnosticsURL: URL? = TokenUsageAntigravityImporter.defaultDiagnosticsURL(),
        stateURL: URL? = TokenUsageAntigravityImporter.defaultStateURL(),
        fileManager: FileManager = .default,
        forceTemporaryCopyFallback: Bool = false
    ) {
        self.conversationsDirectory = conversationsDirectory
        self.labelTimelineURL = labelTimelineURL
        self.diagnosticsURL = diagnosticsURL
        self.stateURL = stateURL
        self.fileManager = fileManager
        self.forceTemporaryCopyFallback = forceTemporaryCopyFallback
    }
}
