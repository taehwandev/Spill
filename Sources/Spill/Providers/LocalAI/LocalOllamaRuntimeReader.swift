import Foundation

struct LocalOllamaRuntimeSummary: Equatable, Sendable {
    let activeModel: String?
}

enum LocalOllamaRuntimeReader {
    static func runtimeSummary(
        executablePath: String?,
        shouldCancel: @escaping () -> Bool = { false }
    ) -> LocalOllamaRuntimeSummary? {
        guard let executablePath,
              !shouldCancel(),
              let output = LocalCommandRunner.output(
                executablePath: executablePath,
                arguments: ["ps"],
                timeout: 1.0,
                shouldCancel: shouldCancel
              )
        else {
            return nil
        }
        guard !shouldCancel() else {
            return nil
        }

        return LocalOllamaRuntimeSummary(activeModel: activeModel(from: output))
    }

    private static func activeModel(from output: String) -> String? {
        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty,
                  !trimmedLine.hasPrefix("NAME")
            else {
                continue
            }

            return trimmedLine
                .split(whereSeparator: \.isWhitespace)
                .first
                .map(String.init)
        }

        return nil
    }
}
