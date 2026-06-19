import Foundation

struct PrivateUsageConnectionCode: Equatable, Sendable {
    static let prefix = "spill-v1"

    let grantCode: String
    let keyWrappingSecret: PrivateUsageKeyWrappingSecret

    init(rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              parts[0] == Self.prefix,
              Self.isSafeGrantCode(parts[1])
        else {
            throw PrivateUsageUploadError.invalidConnectionCode
        }

        grantCode = parts[1]
        keyWrappingSecret = try PrivateUsageKeyWrappingSecret(rawValue: parts[2])
    }

    private static func isSafeGrantCode(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9._-]{8,256}$"#, options: .regularExpression) != nil
    }
}
