import Foundation

public enum AppEnvironment: String, Sendable { case development, staging, production }
public struct AppConfiguration: Sendable {
    public let environment: AppEnvironment
    public let supabaseURL: URL
    public let publishableKey: String
    public init(environment: AppEnvironment, supabaseURL: URL, publishableKey: String) throws {
        guard supabaseURL.scheme == "https", supabaseURL.host != nil,
              !publishableKey.isEmpty, !publishableKey.contains("service_role") else {
            throw ConfigurationError.invalid
        }
        self.environment = environment; self.supabaseURL = supabaseURL; self.publishableKey = publishableKey
    }
}
public enum ConfigurationError: Error { case invalid, unavailable }
public protocol CredentialStore: Sendable {
    func read(account: String) throws -> Data?
    func write(_ data: Data, account: String) throws
    func remove(account: String) throws
}
public protocol AccountSession: Sendable {
    var ownerID: UUID { get async throws }
    func accessToken() async throws -> String
}
// Sign in with Apple exchange is the approved auth adapter boundary.
// No guest identity or email OTP behavior is introduced in Phase 0.
