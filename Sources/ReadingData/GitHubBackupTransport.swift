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

/// A file listed from one immutable repository snapshot. Its commit identifies
/// that snapshot, not an invented creation date; creation comes from the manifest.
public struct GitHubBackupListing: Equatable, Sendable {
    public let id: UUID
    public let path: String
    public let byteCount: Int
    public let snapshotCommitSHA: String
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
        guard validToken(personalAccessToken) else { throw GitHubBackupError.invalidCredential }
        try await verifyRepository(token: personalAccessToken, invalidateStoredCredential: false)
        try credentials.write(Data(personalAccessToken.utf8), account: repository.credentialAccount)
    }
    public func disconnect() throws { try credentials.remove(account: repository.credentialAccount) }

    public func versions() async throws -> [GitHubBackupListing] {
        let token = try credential(); try await verifyRepository(token: token)
        let latest = try await send("commits?per_page=1", method: "GET", token: token)
        try check(latest)
        guard let commits = try? JSONDecoder().decode([CommitMetadata].self, from: latest.data),
              let commitSHA = commits.first?.sha, validSHA(commitSHA) else { throw GitHubBackupError.invalidResponse }
        let commit = try await send("git/commits/\(commitSHA)", method: "GET", token: token)
        try check(commit)
        guard let metadata = try? JSONDecoder().decode(TreeCommit.self, from: commit.data), validSHA(metadata.tree.sha) else {
            throw GitHubBackupError.invalidResponse
        }
        let response = try await send("git/trees/\(metadata.tree.sha)?recursive=1", method: "GET", token: token)
        try check(response)
        guard let tree = try? JSONDecoder().decode(TreeListing.self, from: response.data), !tree.truncated else {
            throw GitHubBackupError.invalidResponse
        }
        var values: [GitHubBackupListing] = []; var paths = Set<String>()
        for entry in tree.tree {
            guard entry.path.hasPrefix("backups/"), entry.path.hasSuffix(".zip") else { continue }
            let parts = entry.path.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 2, let id = UUID(uuidString: String(parts[1].dropLast(4))),
                  entry.path == "backups/\(id.uuidString.lowercased()).zip",
                  entry.type == "blob", entry.mode == "100644" || entry.mode == "100755",
                  validSHA(entry.sha), let size = entry.size, size >= 0, size <= 50 * 1024 * 1024,
                  paths.insert(entry.path).inserted else { throw GitHubBackupError.invalidResponse }
            values.append(.init(id: id, path: entry.path, byteCount: size, snapshotCommitSHA: commitSHA))
        }
        return values.sorted { $0.path < $1.path }
    }

    public func download(_ version: GitHubBackupListing) async throws -> ValidatedPortableBackup {
        guard version.path == "backups/\(version.id.uuidString.lowercased()).zip", validSHA(version.snapshotCommitSHA),
              version.byteCount >= 0, version.byteCount <= 50 * 1024 * 1024 else { throw GitHubBackupError.invalidResponse }
        let token = try credential(); try await verifyRepository(token: token)
        let response = try await send("contents/\(version.path)?ref=\(version.snapshotCommitSHA)", method: "GET", token: token, raw: true)
        try check(response)
        guard response.data.count == version.byteCount else { throw PortableBackupError.integrityMismatch }
        return try codec.decode(response.data)
    }

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
              let token = String(data: bytes, encoding: .utf8), validToken(token) else {
            throw GitHubBackupError.authenticationRequired
        }
        return token
    }
    private func verifyRepository(token: String, invalidateStoredCredential: Bool = true) async throws {
        let response = try await send("", method: "GET", token: token)
        try check(response, invalidateStoredCredential: invalidateStoredCredential)
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
        request.setValue("ReadingCompanion", forHTTPHeaderField: "User-Agent")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        do { return try await client.send(request) }
        catch let error as GitHubBackupError { throw error }
        catch { throw GitHubBackupError.networkUnavailable }
    }
    private func check(_ response: GitHubBackupHTTPResponse, invalidateStoredCredential: Bool = true) throws {
        if response.status == 401 {
            if invalidateStoredCredential { try credentials.remove(account: repository.credentialAccount) }
            throw GitHubBackupError.authenticationRequired
        }
        if response.status == 429 || (response.status == 403 && (response.retryAfter != nil || response.remainingRateLimit == "0")) { throw GitHubBackupError.rateLimited }
        if response.status == 403 { throw GitHubBackupError.insufficientPermissions }
        if response.status == 404 { throw GitHubBackupError.repositoryUnavailable }
        if response.status >= 500 { throw GitHubBackupError.serverUnavailable }
        guard (200..<300).contains(response.status) else { throw GitHubBackupError.invalidResponse }
    }
    private func validSHA(_ value: String) -> Bool { value.count == 40 && value.allSatisfy { "0123456789abcdef".contains($0) } }
    private func validToken(_ value: String) -> Bool {
        value.hasPrefix("github_pat_") && value.count > 11 && value.count <= 1024 && value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_").contains($0)
        }
    }
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
    private struct TreeCommit: Decodable { let tree: CommitMetadata }
    private struct TreeListing: Decodable { let truncated: Bool; let tree: [TreeEntry] }
    private struct TreeEntry: Decodable { let path: String; let mode: String; let type: String; let sha: String; let size: Int? }
}
