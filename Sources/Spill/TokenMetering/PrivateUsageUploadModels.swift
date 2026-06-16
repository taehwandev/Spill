import CryptoKit
import Foundation
import SystemConfiguration

enum PrivateUsageUploadFeatureAvailability {
    static var isEnabledInCurrentBuild: Bool {
        return true
    }
}

enum PrivateUsageUploadEnvironment: String, CaseIterable, Codable, Identifiable, Sendable {
    static let environmentOverrideEnvironmentKey = "SPILL_PRIVATE_USAGE_ENVIRONMENT"
    static let environmentInfoDictionaryKey = "SPILLPrivateUsageEnvironment"

    case development
    case production

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .development:
            return "Development"
        case .production:
            return "Production"
        }
    }

    var detail: String {
        switch self {
        case .development:
            return "Uses the local Supabase relay and separate development credentials."
        case .production:
            return "Uses the live Spill relay and separate production credentials."
        }
    }

    var keychainService: String {
        "dev.spill.private-usage.\(rawValue)"
    }

    var stateKeyNamespace: String {
        "privateUsageUpload.\(rawValue)"
    }

    static var defaultValue: Self {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    static func normalized(rawValue: String?) -> Self {
        guard let rawValue, let environment = Self(rawValue: rawValue) else {
            return defaultValue
        }

        return environment
    }

    static func resolvedFromEnvironment(
        _ processEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self? {
        normalizedExplicit(rawValue: processEnvironment[environmentOverrideEnvironmentKey])
    }

    static func resolvedFromConfiguration(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) -> Self? {
        resolvedFromEnvironment(processEnvironment)
            ?? normalizedExplicit(rawValue: bundleInfo?[environmentInfoDictionaryKey] as? String)
    }

    private static func normalizedExplicit(rawValue: String?) -> Self? {
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }

        return Self(rawValue: rawValue.lowercased())
    }
}

enum PrivateUsageWebConnection {
    static let webURLOverrideEnvironmentKey = "SPILL_PRIVATE_USAGE_WEB_URL"
    static let webURLInfoDictionaryKey = "SPILLPrivateUsageWebURL"

    static func connectDeviceURL(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) -> URL? {
        if let override = processEnvironment[webURLOverrideEnvironmentKey],
           let url = sanitizedConnectDeviceURL(override)
        {
            return url
        }
        if let configuredURL = bundleInfo?[webURLInfoDictionaryKey] as? String,
           let url = sanitizedConnectDeviceURL(configuredURL)
        {
            return url
        }

        return nil
    }

    private static func sanitizedConnectDeviceURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              let host = url.host
        else {
            return nil
        }

        if scheme == "https" {
            return url
        }

        if scheme == "http", host == "localhost" {
            return url
        }

        return nil
    }
}

enum PrivateUsageRelayEndpoint {
    static let relayURLOverrideEnvironmentKey = "SPILL_PRIVATE_USAGE_RELAY_URL"
    static let relayURLInfoDictionaryKey = "SPILLPrivateUsageRelayURL"

    static func relayURL(
        environment: PrivateUsageUploadEnvironment,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) -> URL? {
        if let override = processEnvironment[relayURLOverrideEnvironmentKey],
           let url = sanitizedRelayURL(override)
        {
            return url
        }
        if let configuredURL = bundleInfo?[relayURLInfoDictionaryKey] as? String,
           let url = sanitizedRelayURL(configuredURL)
        {
            return url
        }

        return nil
    }

    static func isSafeRelayURL(_ url: URL) -> Bool {
        if url.scheme == "https" {
            return true
        }

        if url.scheme == "http", url.host == "localhost" {
            return true
        }

        return false
    }

    private static func sanitizedRelayURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              isSafeRelayURL(url)
        else {
            return nil
        }

        return url
    }
}

enum PrivateUsageDeviceName {
    static func current(
        copyComputerName: () -> String? = {
            SCDynamicStoreCopyComputerName(nil, nil) as String?
        },
        fallbackHostName: String? = Host.current().localizedName
    ) -> String? {
        sanitize(copyComputerName()) ?? sanitize(fallbackHostName)
    }

    private static func sanitize(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else {
            return nil
        }

        guard trimmed.rangeOfCharacter(from: .controlCharacters) == nil else {
            return nil
        }

        return trimmed
    }
}

struct PrivateUsageDeviceCredential: Codable, Equatable, Sendable {
    let deviceID: String
    let credential: String
    let tokenType: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case credential
        case tokenType = "token_type"
        case createdAt = "created_at"
    }

    var authorizationToken: String {
        if credential.hasPrefix("spill_device_v1_") {
            return credential
        }

        if tokenType == "spill_device_v1" {
            return "spill_device_v1_\(credential)"
        }

        return credential
    }
}

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

enum PrivateUsageConnectionDeepLink {
    static func connectionCode(from url: URL) -> String? {
        guard url.scheme == "spill",
              url.host == "private-usage",
              url.path == "/connect",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              isAllowedConnectionCodeQueryValue(code)
        else {
            return nil
        }

        return code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isAllowedConnectionCodeQueryValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 512 else {
            return false
        }

        return trimmed.range(of: #"^[A-Za-z0-9._:-]+$"#, options: .regularExpression) != nil
    }
}

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

struct PrivateUsageKeyEnvelope: Codable, Equatable, Sendable {
    static let algorithm = "aes-256-gcm-hkdf-sha256"

    let keyVersion: Int
    let wrappingKeyID: String
    let algorithm: String
    let wrappedKey: String

    enum CodingKeys: String, CodingKey {
        case keyVersion = "key_version"
        case wrappingKeyID = "wrapping_key_id"
        case algorithm
        case wrappedKey = "wrapped_key"
    }
}

struct PrivateUsageEncryptedBucket: Codable, Equatable, Sendable {
    let bucketKey: String
    let bucketKind: String
    let bucketStartAt: String
    let bucketEndAt: String
    let timezone: String
    let schemaVersion: Int
    let keyVersion: Int
    let ciphertext: String
    let ciphertextHash: String

    enum CodingKeys: String, CodingKey {
        case bucketKey = "bucket_key"
        case bucketKind = "bucket_kind"
        case bucketStartAt = "bucket_start_at"
        case bucketEndAt = "bucket_end_at"
        case timezone
        case schemaVersion = "schema_version"
        case keyVersion = "key_version"
        case ciphertext
        case ciphertextHash = "ciphertext_hash"
    }
}

struct PrivateUsageGrantExchangeRequest: Codable, Equatable, Sendable {
    let grantCode: String
    let installID: String
    let deviceName: String?
    let deviceKeyFingerprint: String?

    enum CodingKeys: String, CodingKey {
        case grantCode = "grant_code"
        case installID = "install_id"
        case deviceName = "device_name"
        case deviceKeyFingerprint = "device_key_fingerprint"
    }
}

struct PrivateUsageGrantExchangeResponse: Codable, Equatable, Sendable {
    let deviceID: String
    let credential: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case credential
        case tokenType = "token_type"
    }
}

struct PrivateUsageUploadBucketsRequest: Codable, Equatable, Sendable {
    let keyEnvelopes: [PrivateUsageKeyEnvelope]
    let buckets: [PrivateUsageEncryptedBucket]

    enum CodingKeys: String, CodingKey {
        case keyEnvelopes = "key_envelopes"
        case buckets
    }
}

struct PrivateUsageUploadResponse: Codable, Equatable, Sendable {
    let accepted: Int
    let uploadedAt: String?

    enum CodingKeys: String, CodingKey {
        case accepted
        case uploadedAt = "uploaded_at"
    }
}

struct PrivateUsageDeviceCheckResponse: Codable, Equatable, Sendable {
    let connected: Bool
}

struct PrivateUsageUploadStatus: Equatable, Sendable {
    let isConnected: Bool
    let isEnabled: Bool
    let queuedBucketCount: Int
    let lastSuccessfulUploadAt: Date?
    let lastFailedUploadAt: Date?
    let lastFailureReason: String?
    let lastAckedBucketKey: String?
    let nextAutomaticAttemptAfter: Date?

    static let disconnected = PrivateUsageUploadStatus(
        isConnected: false,
        isEnabled: false,
        queuedBucketCount: 0,
        lastSuccessfulUploadAt: nil,
        lastFailedUploadAt: nil,
        lastFailureReason: nil,
        lastAckedBucketKey: nil,
        nextAutomaticAttemptAfter: nil
    )
}

struct PrivateUsageUploadRunResult: Equatable, Sendable {
    let accepted: Int
    let attemptedBucketCount: Int
    let uploadedAt: Date?

    var didUpload: Bool {
        accepted > 0
    }
}

enum PrivateUsageUploadError: Error, Equatable {
    case invalidConnectionCode
    case invalidGrantCode
    case uploadDisabled
    case missingCredential
    case missingSealingKey
    case missingKeyWrappingSecret
    case invalidRelayURL
    case invalidRelayResponse
    case relay(status: Int, reason: String?)
    case keychainReadFailed
    case keychainWriteFailed
    case encryptionFailed
    case keyWrappingFailed
}

extension PrivateUsageUploadError {
    var isRevokedConnection: Bool {
        if case let .relay(status, reason) = self {
            return status == 403 || reason == "device_forbidden" || reason == "connection_required"
        }

        return false
    }

    var safeUserMessage: String {
        switch self {
        case .invalidConnectionCode:
            return TokenMeteringL10n.text(.privateUsageUploadInvalidConnectionCodeMessage)
        case .invalidGrantCode:
            return TokenMeteringL10n.text(.privateUsageUploadInvalidGrantCodeMessage)
        case .uploadDisabled:
            return TokenMeteringL10n.text(.privateUsageUploadDisabledMessage)
        case .missingCredential:
            return TokenMeteringL10n.text(.privateUsageUploadMissingCredentialMessage)
        case .missingSealingKey:
            return TokenMeteringL10n.text(.privateUsageUploadMissingSealingKeyMessage)
        case .missingKeyWrappingSecret:
            return TokenMeteringL10n.text(.privateUsageUploadMissingKeyWrappingSecretMessage)
        case .invalidRelayURL:
            return TokenMeteringL10n.text(.privateUsageUploadRelayURLUnavailableMessage)
        case .invalidRelayResponse:
            return TokenMeteringL10n.text(.privateUsageUploadInvalidRelayResponseMessage)
        case let .relay(status, reason):
            if status == 403 || reason == "device_forbidden" || reason == "grant_forbidden" {
                return TokenMeteringL10n.text(.privateUsageUploadConnectionExpiredMessage)
            }
            if status == 401 {
                return TokenMeteringL10n.text(.privateUsageUploadConnectionRequiredMessage)
            }
            return TokenMeteringL10n.text(.privateUsageUploadRelayUnavailableMessage)
        case .keychainReadFailed:
            return TokenMeteringL10n.text(.privateUsageUploadKeychainReadFailedMessage)
        case .keychainWriteFailed:
            return TokenMeteringL10n.text(.privateUsageUploadKeychainWriteFailedMessage)
        case .encryptionFailed:
            return TokenMeteringL10n.text(.privateUsageUploadEncryptionFailedMessage)
        case .keyWrappingFailed:
            return TokenMeteringL10n.text(.privateUsageUploadKeyWrappingFailedMessage)
        }
    }
}

struct PrivateUsageUploadPersistence: Codable, Equatable, Sendable {
    var acknowledgedCiphertextHashesByBucketKey: [String: String] = [:]
    var lastSuccessfulUploadAt: String?
    var lastFailedUploadAt: String?
    var lastFailureReason: String?
    var lastAutomaticAttemptDayID: String?
    var lastAckedBucketKey: String?

    static let empty = PrivateUsageUploadPersistence()
}
