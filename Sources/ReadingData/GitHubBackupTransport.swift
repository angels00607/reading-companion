import Foundation

public enum GitHubBackupError: Error, Equatable {
    case invalidRepository, invalidCredential, authenticationRequired, insufficientPermissions
    case repositoryUnavailable, repositoryNotPrivate, repositoryMismatch, rateLimited
    case networkUnavailable, invalidResponse, serverUnavailable, versionCollision, backupTooLarge
}

/// One configured repository; user input never supplies a network host or redirect target.
public struct GitHubBackupRepository: Equatable, Sendable {
    public let owner: String
    public let name: String
    public init(owner: String, name: String) throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        guard !owner.isEmpty, !name.isEmpty, owner.count <= 100, name.count <= 100,
              owner != ".", owner != "..", name != ".", name != "..",
              owner.unicodeScalars.allSatisfy(allowed.contains), name.unicodeScalars.allSatisfy(allowed.contains) else {
            throw GitHubBackupError.invalidRepository
        }
        self.owner = owner; self.name = name
    }
    public var fullName: String { "\(owner)/\(name)" }
    var credentialAccount: String { "github-backup:\(fullName.lowercased())" }
}

/// Transient request data is the only place the PAT leaves Keychain. No raw error
/// body, request, URLSession error, or response token is exposed to UI/logging.
public struct GitHubBackupHTTPResponse: Sendable {
    public let status: Int
    public let data: Data
    public let retryAfter: String?
    public let remainingRateLimit: String?
    public init(status: Int, data: Data, retryAfter: String? = nil, remainingRateLimit: String? = nil) {
        self.status = status; self.data = data; self.retryAfter = retryAfter; self.remainingRateLimit = remainingRateLimit
    }
}
public protocol GitHubBackupHTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> GitHubBackupHTTPResponse
}

private final class NoBackupRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public final class GitHubBackupURLSessionClient: GitHubBackupHTTPClient, @unchecked Sendable {
    private let session: URLSession
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60; configuration.timeoutIntervalForResource = 120
        session = URLSession(configuration: configuration, delegate: NoBackupRedirects(), delegateQueue: nil)
    }
    public func send(_ request: URLRequest) async throws -> GitHubBackupHTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.url?.scheme == "https", http.url?.host == "api.github.com" else {
                throw GitHubBackupError.invalidResponse
            }
            return .init(status: http.statusCode, data: data,
                retryAfter: http.value(forHTTPHeaderField: "Retry-After"),
                remainingRateLimit: http.value(forHTTPHeaderField: "X-RateLimit-Remaining"))
        } catch let error as GitHubBackupError { throw error }
        catch { throw GitHubBackupError.networkUnavailable }
    }
}

public struct GitHubBackupVersion: Codable, Equatable, Sendable {
    public let id: UUID
    public let path: String
    public let commitSHA: String
}

public actor GitHubBackupTransport {
    private let repository: GitHubBackupRepository
    private let credentials: any CredentialStore
    private let client: any GitHubBackupHTTPClient
    private let codec: PortableBackupCodec
    public init(repository: GitHubBackupRepository, credentials: any CredentialStore,
                client: any GitHubBackupHTTPClient = GitHubBackupURLSessionClient(), codec: PortableBackupCodec = .init()) {
        self.repository = repository; self.credentials = credentials; self.client = client; self.codec = codec
    }

    /// V1 accepts fine-grained PAT syntax only. Permission and single-repository
    /// scoping are configured on GitHub; repository metadata verifies the destination.
    public func connect(personalAccessToken: String) async throws {
        guard personalAccessToken.hasPrefix("github_pat_"), personalAccessToken.count <= 1024,
              personalAccessToken.count > 11, personalAccessToken.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_").contains($0)
              }) else { throw GitHubBackupError.invalidCredential }
        try await verifyRepository(token: personalAccessToken)
        try credentials.write(Data(personalAccessToken.utf8), account: repository.credentialAccount)
    }
    public func disconnect() throws { try credentials.remove(account: repository.credentialAccount) }

    /// Stable ID supplied by the caller survives retry. Existing matching bytes
    /// acknowledge a lost-response retry; different bytes never overwrite history.
    public func upload(_ archive: Data, versionID: UUID) async throws -> GitHubBackupVersion {
        _ = try codec.decode(archive)
        // GitHub Contents API supports files up to 100 MB; bound below its endpoint
        // limit and reject as a whole. Independent local export retains codec limits.
        guard archive.count <= 50 * 1024 * 1024 else { throw GitHubBackupError.backupTooLarge }
        let token = try credential()
        try await verifyRepository(token: token)
        let path = "backups/\(versionID.uuidString.lowercased()).zip"
        if let existing = try await existingVersion(path: path, token: token, archive: archive, versionID: versionID) { return existing }
        let body = UploadBody(message: "Reading Companion manual backup \(versionID.uuidString.lowercased())", content: archive.base64EncodedString())
        let response = try await send("contents/\(path)", method: "PUT", token: token, body: JSONEncoder().encode(body))
        if response.status == 409 || response.status == 422 {
            // Concurrent request or response lost after apply: reread the same ID.
            if let existing = try await existingVersion(path: path, token: token, archive: archive, versionID: versionID) { return existing }
            throw GitHubBackupError.versionCollision
        }
        try check(response)
        guard response.status == 201, let result = try? JSONDecoder().decode(UploadResult.self, from: response.data),
              validSHA(result.commit.sha), result.content.path == path else { throw GitHubBackupError.invalidResponse }
        return .init(id: versionID, path: path, commitSHA: result.commit.sha)
    }

    private func credential() throws -> String {
        guard let bytes = try credentials.read(account: repository.credentialAccount),
              let token = String(data: bytes, encoding: .utf8), token.hasPrefix("github_pat_") else {
            throw GitHubBackupError.authenticationRequired
        }
        return token
    }
    private func verifyRepository(token: String) async throws {
        let response = try await send("", method: "GET", token: token)
        try check(response)
        guard let info = try? JSONDecoder().decode(RepositoryMetadata.self, from: response.data) else { throw GitHubBackupError.invalidResponse }
        guard info.full_name.caseInsensitiveCompare(repository.fullName) == .orderedSame else { throw GitHubBackupError.repositoryMismatch }
        guard info.isPrivate else { throw GitHubBackupError.repositoryNotPrivate }
        guard !info.archived, !info.disabled, info.permissions.push else { throw GitHubBackupError.insufficientPermissions }
    }
    private func existingVersion(path: String, token: String, archive: Data, versionID: UUID) async throws -> GitHubBackupVersion? {
        let response = try await send("contents/\(path)", method: "GET", token: token, raw: true)
        if response.status == 404 { return nil }
        try check(response)
        guard response.data == archive else {
            throw GitHubBackupError.versionCollision
        }
        // Contents SHA identifies the file blob, not its commit. Retrieve the
        // path's latest commit to provide truthful committed-version metadata.
        let commits = try await send("commits?path=\(path)&per_page=1", method: "GET", token: token)
        try check(commits)
        guard let values = try? JSONDecoder().decode([CommitMetadata].self, from: commits.data),
              let sha = values.first?.sha, validSHA(sha) else { throw GitHubBackupError.invalidResponse }
        return .init(id: versionID, path: path, commitSHA: sha)
    }
    private func send(_ suffix: String, method: String, token: String, body: Data? = nil, raw: Bool = false) async throws -> GitHubBackupHTTPResponse {
        let base = "https://api.github.com/repos/\(repository.fullName)"
        guard let url = URL(string: base + (suffix.isEmpty ? "" : "/" + suffix)), url.host == "api.github.com" else { throw GitHubBackupError.invalidRepository }
        var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(raw ? "application/vnd.github.raw+json" : "application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        do { return try await client.send(request) }
        catch let error as GitHubBackupError { throw error }
        catch { throw GitHubBackupError.networkUnavailable }
    }
    private func check(_ response: GitHubBackupHTTPResponse) throws {
        if response.status == 401 {
            try credentials.remove(account: repository.credentialAccount)
            throw GitHubBackupError.authenticationRequired
        }
        if response.status == 429 || (response.status == 403 && (response.retryAfter != nil || response.remainingRateLimit == "0")) { throw GitHubBackupError.rateLimited }
        if response.status == 403 { throw GitHubBackupError.insufficientPermissions }
        if response.status == 404 { throw GitHubBackupError.repositoryUnavailable }
        if response.status >= 500 { throw GitHubBackupError.serverUnavailable }
        guard (200..<300).contains(response.status) else { throw GitHubBackupError.invalidResponse }
    }
    private func validSHA(_ value: String) -> Bool { value.count == 40 && value.allSatisfy { "0123456789abcdef".contains($0) } }
    private struct RepositoryMetadata: Decodable {
        let full_name: String
        let isPrivate: Bool
        let archived: Bool
        let disabled: Bool
        let permissions: Permissions
        struct Permissions: Decodable { let push: Bool }
        enum CodingKeys: String, CodingKey { case full_name, isPrivate = "private", archived, disabled, permissions }
    }
    private struct UploadBody: Encodable { let message: String; let content: String }
    private struct UploadResult: Decodable { let content: PathMetadata; let commit: CommitMetadata }
    private struct PathMetadata: Decodable { let path: String }
    private struct CommitMetadata: Decodable { let sha: String }
}
