import Foundation

final class TokenUsageClaudeCodeImporter {
    let projectsDirectory: URL
    let labelTimelineURL: URL
    let stateURL: URL?
    let fileManager: FileManager

    init(
        projectsDirectory: URL = TokenUsageClaudeCodeImporter.defaultProjectsDirectory(),
        labelTimelineURL: URL = TokenUsageClaudeCodeImporter.defaultLabelTimelineURL(),
        stateURL: URL? = TokenUsageClaudeCodeImporter.defaultStateURL(),
        fileManager: FileManager = .default
    ) {
        self.projectsDirectory = projectsDirectory
        self.labelTimelineURL = labelTimelineURL
        self.stateURL = stateURL
        self.fileManager = fileManager
    }
}
