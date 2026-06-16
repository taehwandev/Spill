import Foundation

enum LocalAICommandMetadataReader {
    static func metadata(for executablePaths: [String: String]) -> [LocalAIToolKind: LocalAIToolMetadata] {
        var metadata = [LocalAIToolKind: LocalAIToolMetadata]()

        for kind in LocalAIToolKind.allCases {
            guard let executablePath = kind.executableNames.compactMap({ executablePaths[$0] }).first,
                  let version = version(executablePath: executablePath)
            else {
                continue
            }

            metadata[kind] = LocalAIToolMetadata(model: nil, version: version, source: "Command")
        }

        return metadata
    }

    private static func version(executablePath: String) -> String? {
        guard let output = LocalCommandRunner.output(
            executablePath: executablePath,
            arguments: ["--version"],
            timeout: 1.0
        ) else {
            return nil
        }

        return versionText(from: output)
    }

    private static func versionText(from output: String) -> String? {
        guard let firstLine = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !firstLine.isEmpty
        else {
            return nil
        }

        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ",:;()"))
        let tokens = firstLine
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        return tokens.first { token in
            token.contains { character in
                character.isNumber
            }
        }?.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
}
