import Foundation

enum LocalAICommandLineParser {
    static func tokens(from commandLine: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var quote: Character?
        var isEscaped = false

        for character in commandLine {
            if isEscaped {
                currentToken.append(character)
                isEscaped = false
                continue
            }

            if character == "\\" {
                isEscaped = true
                continue
            }

            if let currentQuote = quote {
                if character == currentQuote {
                    quote = nil
                } else {
                    currentToken.append(character)
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                continue
            }

            if character.isWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                continue
            }

            currentToken.append(character)
        }

        if isEscaped {
            currentToken.append("\\")
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    static func executableToken(from tokens: [String]) -> String? {
        guard let firstToken = tokens.first else {
            return nil
        }

        guard firstToken.matchesExecutable(named: "env") else {
            return firstToken
        }

        return tokens.dropFirst().first { token in
            !token.hasPrefix("-") && !token.contains("=")
        }
    }

    static func modelArgument(in commandLine: String) -> String? {
        let tokens = tokens(from: commandLine)

        for index in tokens.indices {
            let token = tokens[index]

            if token == "--model" || token == "-m" {
                let nextIndex = tokens.index(after: index)
                guard nextIndex < tokens.endIndex else {
                    continue
                }

                let value = sanitizedModelValue(tokens[nextIndex])
                if value != nil {
                    return value
                }
            }

            if token.hasPrefix("--model=") {
                let value = String(token.dropFirst("--model=".count))
                if let value = sanitizedModelValue(value) {
                    return value
                }
            }
        }

        return nil
    }

    private static func sanitizedModelValue(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'"))
        )

        guard !trimmedValue.isEmpty, !trimmedValue.hasPrefix("-") else {
            return nil
        }

        return trimmedValue
    }
}

extension String {
    func matchesExecutable(named name: String) -> Bool {
        let token = trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedToken = token.lowercased()
        let lowercasedName = name.lowercased()

        return lowercasedToken == lowercasedName
            || lowercasedToken.hasSuffix("/\(lowercasedName)")
            || URL(fileURLWithPath: lowercasedToken).lastPathComponent == lowercasedName
    }
}
