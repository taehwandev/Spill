import CryptoKit
import Foundation

struct PrivateUsageKeyWrappingSecret: Codable, Equatable, Sendable {
    let rawValue: String
    let keyID: String

    enum CodingKeys: String, CodingKey {
        case rawValue = "secret"
        case keyID = "key_id"
    }

    init(rawValue: String) throws {
        guard rawValue.range(of: #"^[A-Za-z0-9_-]{43,128}$"#, options: .regularExpression) != nil,
              let secretData = Self.decodeBase64URL(rawValue),
              secretData.count >= 32
        else {
            throw PrivateUsageUploadError.invalidConnectionCode
        }

        self.rawValue = rawValue
        keyID = Self.makeKeyID(secretData)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .rawValue)
        try self.init(rawValue: rawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawValue, forKey: .rawValue)
        try container.encode(keyID, forKey: .keyID)
    }

    func secretData() throws -> Data {
        guard let data = Self.decodeBase64URL(rawValue), data.count >= 32 else {
            throw PrivateUsageUploadError.missingKeyWrappingSecret
        }

        return data
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - (base64.count % 4)) % 4
        base64.append(String(repeating: "=", count: padding))
        return Data(base64Encoded: base64)
    }

    private static func makeKeyID(_ secretData: Data) -> String {
        var input = Data("spill-private-usage-key-wrap-id-v1".utf8)
        input.append(secretData)
        return SHA256.hash(data: input)
            .prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
