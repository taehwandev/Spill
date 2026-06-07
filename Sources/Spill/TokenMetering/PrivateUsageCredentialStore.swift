import Foundation
import Security

protocol PrivateUsageCredentialStoring: Sendable {
    func loadCredential() throws -> PrivateUsageDeviceCredential?
    func saveCredential(_ credential: PrivateUsageDeviceCredential) throws
    func clearCredential() throws
    func loadKeyWrappingSecret() throws -> PrivateUsageKeyWrappingSecret?
    func saveKeyWrappingSecret(_ secret: PrivateUsageKeyWrappingSecret) throws
    func clearKeyWrappingSecret() throws
    func loadSealingKeyData() throws -> Data?
    func saveSealingKeyData(_ data: Data) throws
}

final class PrivateUsageKeychainCredentialStore: PrivateUsageCredentialStoring, @unchecked Sendable {
    private enum Account {
        static let credential = "device-credential"
        static let keyWrappingSecret = "browser-key-wrap-secret"
        static let sealingKey = "bucket-sealing-key"
    }

    private let service: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(service: String = "dev.spill.private-usage") {
        self.service = service
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadCredential() throws -> PrivateUsageDeviceCredential? {
        guard let data = try loadData(account: Account.credential) else {
            return nil
        }

        do {
            return try decoder.decode(PrivateUsageDeviceCredential.self, from: data)
        } catch {
            throw PrivateUsageUploadError.keychainReadFailed
        }
    }

    func saveCredential(_ credential: PrivateUsageDeviceCredential) throws {
        do {
            try saveData(encoder.encode(credential), account: Account.credential)
        } catch let error as PrivateUsageUploadError {
            throw error
        } catch {
            throw PrivateUsageUploadError.keychainWriteFailed
        }
    }

    func clearCredential() throws {
        try deleteData(account: Account.credential)
    }

    func loadKeyWrappingSecret() throws -> PrivateUsageKeyWrappingSecret? {
        guard let data = try loadData(account: Account.keyWrappingSecret) else {
            return nil
        }

        do {
            return try decoder.decode(PrivateUsageKeyWrappingSecret.self, from: data)
        } catch {
            throw PrivateUsageUploadError.keychainReadFailed
        }
    }

    func saveKeyWrappingSecret(_ secret: PrivateUsageKeyWrappingSecret) throws {
        do {
            try saveData(encoder.encode(secret), account: Account.keyWrappingSecret)
        } catch let error as PrivateUsageUploadError {
            throw error
        } catch {
            throw PrivateUsageUploadError.keychainWriteFailed
        }
    }

    func clearKeyWrappingSecret() throws {
        try deleteData(account: Account.keyWrappingSecret)
    }

    func loadSealingKeyData() throws -> Data? {
        try loadData(account: Account.sealingKey)
    }

    func saveSealingKeyData(_ data: Data) throws {
        try saveData(data, account: Account.sealingKey)
    }

    private func loadData(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw PrivateUsageUploadError.keychainReadFailed
        }

        return data
    }

    private func saveData(_ data: Data, account: String) throws {
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            return
        }

        if status == errSecDuplicateItem {
            let update: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            let updateStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw PrivateUsageUploadError.keychainWriteFailed
            }
            return
        }

        throw PrivateUsageUploadError.keychainWriteFailed
    }

    private func deleteData(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PrivateUsageUploadError.keychainWriteFailed
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

final class PrivateUsageUploadStateStore: @unchecked Sendable {
    private enum Keys {
        static let state = "privateUsageUploadStateV1"
        static let installID = "privateUsageInstallID"
    }

    private let namespace: String
    private let defaults: UserDefaults
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        environment: PrivateUsageUploadEnvironment = .defaultValue
    ) {
        namespace = environment.stateKeyNamespace
        self.defaults = defaults
    }

    func load() -> PrivateUsageUploadPersistence {
        lock.withLock {
            guard let data = defaults.data(forKey: namespacedKey(Keys.state)),
                  let state = try? JSONDecoder().decode(PrivateUsageUploadPersistence.self, from: data)
            else {
                return .empty
            }

            return state
        }
    }

    func save(_ state: PrivateUsageUploadPersistence) {
        lock.withLock {
            guard let data = try? JSONEncoder().encode(state) else {
                return
            }

            defaults.set(data, forKey: namespacedKey(Keys.state))
        }
    }

    func installID() -> String {
        lock.withLock {
            if let existing = defaults.string(forKey: namespacedKey(Keys.installID)),
               Self.isSafeInstallID(existing) {
                return existing
            }

            let installID = UUID().uuidString.lowercased()
            defaults.set(installID, forKey: namespacedKey(Keys.installID))
            return installID
        }
    }

    private func namespacedKey(_ key: String) -> String {
        "\(namespace).\(key)"
    }

    private static func isSafeInstallID(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9._:-]{1,160}$"#, options: .regularExpression) != nil
    }
}
