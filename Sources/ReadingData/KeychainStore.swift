import Foundation
import Security

public struct KeychainStore: CredentialStore {
    public let service: String
    public init(service: String) { self.service = service }
    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    public func read(account: String) throws -> Data? {
        var request = query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        return result as? Data
    }
    public func write(_ data: Data, account: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query(account) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var request = query(account)
            attributes.forEach { request[$0.key] = $0.value }
            let added = SecItemAdd(request as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError.status(added) }
        } else if status != errSecSuccess { throw KeychainError.status(status) }
    }
    public func remove(account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }
}
public enum KeychainError: Error { case status(OSStatus) }
