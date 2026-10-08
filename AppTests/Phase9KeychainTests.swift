import XCTest
import Security
import ReadingData

final class Phase9KeychainTests: XCTestCase {
    func testProductionKeychainLifecycleAndProtectionAttributes() throws {
        let service = "ReadingCompanion.tests.Phase9.\(UUID().uuidString)"
        let account = "github-backup:fictional/private-backups"
        let store = try KeychainCredentialStore(service: service)
        defer { try? store.remove(account: account) }
        let first = Data("fictional-first-credential".utf8), replacement = Data("fictional-replacement".utf8)
        XCTAssertNil(try store.read(account: account))
        try store.write(first, account: account)
        XCTAssertTrue(try store.read(account: account) == first)

        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false, kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne]
        var value: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &value), errSecSuccess)
        let attributes = try XCTUnwrap(value as? [String: Any])
        XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertEqual(attributes[kSecAttrSynchronizable as String] as? Bool, false)

        try store.write(replacement, account: account)
        XCTAssertTrue(try store.read(account: account) == replacement)
        try store.remove(account: account)
        XCTAssertNil(try store.read(account: account))
        XCTAssertNoThrow(try store.remove(account: account))
    }
    func testRepositoryAccountsRemainIsolatedThroughRevocation() throws {
        let store = try KeychainCredentialStore(service: "ReadingCompanion.tests.Phase9.\(UUID().uuidString)")
        let first = "github-backup:fictional/first", second = "github-backup:fictional/second"
        defer { try? store.remove(account: first); try? store.remove(account: second) }
        let value = Data("fictional-only".utf8)
        try store.write(value, account: first)
        XCTAssertNil(try store.read(account: second))
        try store.write(value, account: second)
        try store.remove(account: first)
        XCTAssertNil(try store.read(account: first))
        XCTAssertTrue(try store.read(account: second) == value)
    }
}
