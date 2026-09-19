import Foundation

final class TokenUsageClaudeCodeImporter {
    let projectsDirectory: URL
    let labelTimelineURL: URL
    let stateURL: URL?
    let diagnosticsURL: URL?
    let fileManager: FileManager
    let sessionDiscoveryCacheLifetime: TimeInterval
    let now: () -> Date
    var labelTimelineCache = LabelTimelineCache()
    var labelTimelineBytesRead = 0
    var sessionDiscoveryCache: SessionDiscoveryCache?
    var sessionDiscoveryScanCount = 0

    init(
        projectsDirectory: URL = TokenUsageClaudeCodeImporter.defaultProjectsDirectory(),
        labelTimelineURL: URL = TokenUsageClaudeCodeImporter.defaultLabelTimelineURL(),
        stateURL: URL? = TokenUsageClaudeCodeImporter.defaultStateURL(),
        diagnosticsURL: URL? = TokenUsageClaudeCodeImporter.defaultDiagnosticsURL(),
        fileManager: FileManager = .default,
        sessionDiscoveryCacheLifetime: TimeInterval = 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.projectsDirectory = projectsDirectory
        self.labelTimelineURL = labelTimelineURL
        self.stateURL = stateURL
        self.diagnosticsURL = diagnosticsURL
        self.fileManager = fileManager
        self.sessionDiscoveryCacheLifetime = sessionDiscoveryCacheLifetime
        self.now = now
    }
}
