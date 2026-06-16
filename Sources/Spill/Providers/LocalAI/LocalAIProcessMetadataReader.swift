import Foundation

enum LocalAIProcessMetadataReader {
    static func metadata(
        for kind: LocalAIToolKind,
        processCommands: [String]
    ) -> LocalAIToolMetadata? {
        guard !kind.executableNames.isEmpty else {
            return nil
        }

        for command in processCommands where kind.executableNames.contains(where: { executableName in
            LocalAIStatusProvider.commandLine(command, matchesExecutableNamed: executableName)
        }) {
            guard let model = LocalAICommandLineParser.modelArgument(in: command) else {
                continue
            }

            return LocalAIToolMetadata(model: model, version: nil, source: "Process Args")
        }

        return nil
    }
}
