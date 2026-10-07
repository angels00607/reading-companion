import Foundation
import Security

public enum SecureCredentialError: Error, Equatable { case invalidInput, unavailable(OSStatus) }

/// Security.framework is thread-safe; no token cache or fallback file exists.
public final class KeychainCredentialStore: CredentialStore, @unchecked Sendable {
    private let service: String
    public init(service: String = "ReadingCompanion.credentials") throws {
        guard !service.isEmpty, service.count <= 256 else { throw SecureCredentialError.invalidInput }
        self.service = service
    }
    private func query(account: String) throws -> [String: Any] {
        guard !account.isEmpty, account.count <= 256 else { throw SecureCredentialError.invalidInput }
        var value: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false]
        #if os(macOS)
        value[kSecUseDataProtectionKeychain as String] = true
        #endif
        return value
    }
    public func read(account: String) throws -> Data? {
        var value = try query(account: account)
        value[kSecReturnData as String] = true; value[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(value as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw SecureCredentialError.unavailable(status) }
        return data
    }
    public func write(_ data: Data, account: String) throws {
        guard !data.isEmpty, data.count <= 16_384 else { throw SecureCredentialError.invalidInput }
        let base = try query(account: account)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let creation = base.merging(attributes) { _, new in new }
            let added = SecItemAdd(creation as CFDictionary, nil)
            guard added == errSecSuccess else { throw SecureCredentialError.unavailable(added) }
        } else if status != errSecSuccess { throw SecureCredentialError.unavailable(status) }
    }
    public func remove(account: String) throws {
        let status = SecItemDelete(try query(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecureCredentialError.unavailable(status) }
    }
}
