import Foundation

enum TokenUsageAntigravityQuotaCommand {
    static func output(shouldCancel: @escaping () -> Bool) -> Data? {
        guard let executable = executableURL() else { return nil }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("spill-agy-quota-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        } catch { return nil }
        defer { try? FileManager.default.removeItem(at: directory) }
        guard let version = TokenUsageAntigravityQuotaProcess.output(
            executable: executable, arguments: ["--version"], directory: directory,
            timeout: 3, maximumBytes: 4096, shouldCancel: shouldCancel
        ), supportsNativeUsage(version) else { return nil }
        return TokenUsageAntigravityQuotaProcess.output(
            executable: executable,
            arguments: ["-p", "/usage", "--output-format", "json", "--print-timeout", "90s"],
            directory: directory, timeout: 90, shouldCancel: shouldCancel
        )
    }

    static func supportsNativeUsage(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil
        else { return false }
        let parts = text.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else { return false }
        return parts[0] > 1 || (parts[0] == 1 && (parts[1] > 1 || (parts[1] == 1 && parts[2] >= 11)))
    }

    private static func executableURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // This installation's wrapper adds permission flags; prefer its native
        // binary so Spill never supplies an auto-approve option.
        let candidates = [
            home.appendingPathComponent(".local/bin/agy-real"),
            home.appendingPathComponent(".local/bin/agy"),
            URL(fileURLWithPath: "/opt/homebrew/bin/agy"),
            URL(fileURLWithPath: "/usr/local/bin/agy"),
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
