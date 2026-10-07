import XCTest
@testable import ReadingData

private final class BackupMemoryCredentials: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func read(account: String) -> Data? { lock.withLock { values[account] } }
    func write(_ data: Data, account: String) { lock.withLock { values[account] = data } }
    func remove(account: String) { lock.withLock { _ = values.removeValue(forKey: account) } }
}
private actor BackupHTTPFixture: GitHubBackupHTTPClient {
    private var responses: [GitHubBackupHTTPResponse]
    private(set) var requests: [URLRequest] = []
    init(_ responses: [GitHubBackupHTTPResponse]) { self.responses = responses }
    func send(_ request: URLRequest) throws -> GitHubBackupHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw GitHubBackupError.networkUnavailable }
        return responses.removeFirst()
    }
}
final class Phase9GitHubBackupTests: XCTestCase {
    private let token = "github_pat_fictionalTestCredential"
    private let versionID = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
    private let sha = String(repeating: "a", count: 40)
    private func repo() throws -> GitHubBackupRepository { try .init(owner: "reader", name: "private-backups") }
    private func metadata(isPrivate: Bool = true, fullName: String = "reader/private-backups", push: Bool = true) throws -> GitHubBackupHTTPResponse {
        .init(status: 200, data: try JSONSerialization.data(withJSONObject: ["full_name": fullName, "private": isPrivate,
            "archived": false, "disabled": false, "permissions": ["push": push]]))
    }
    private func archive() throws -> Data {
        try PortableBackupCodec().encode(json: Data(#"{"schemaVersion":1,"entities":{"books":[]}}"#.utf8),
            appVersion: "1.0", createdAt: Date(timeIntervalSince1970: 1_791_382_400))
    }
    private func storedCredentials() throws -> BackupMemoryCredentials {
        let value = BackupMemoryCredentials(); value.write(Data(token.utf8), account: try repo().credentialAccount); return value
    }
    func testPublicRepositoryRejectedBeforeCredentialIsStored() async throws {
        let credentials = BackupMemoryCredentials(), http = BackupHTTPFixture([try metadata(isPrivate: false)])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: credentials, client: http)
        do { try await transport.connect(personalAccessToken: token); XCTFail("Public repository must be rejected") }
        catch { XCTAssertEqual(error as? GitHubBackupError, .repositoryNotPrivate) }
        XCTAssertNil(credentials.read(account: try repo().credentialAccount))
    }
    func testRepositoryMismatchRejectedWithoutStoringCredential() async throws {
        let credentials = BackupMemoryCredentials(), http = BackupHTTPFixture([try metadata(fullName: "other/repo")])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: credentials, client: http)
        do { try await transport.connect(personalAccessToken: token); XCTFail("Wrong destination") }
        catch { XCTAssertEqual(error as? GitHubBackupError, .repositoryMismatch) }
        XCTAssertNil(credentials.read(account: try repo().credentialAccount))
    }
    func testReadOnlyRepositoryRejected() async throws {
        let http = BackupHTTPFixture([try metadata(push: false)])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: BackupMemoryCredentials(), client: http)
        do { try await transport.connect(personalAccessToken: token); XCTFail("Write access required") }
        catch { XCTAssertEqual(error as? GitHubBackupError, .insufficientPermissions) }
    }
    func testClassicPATAndHeaderInjectionRejectedBeforeNetwork() async throws {
        let http = BackupHTTPFixture([])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: BackupMemoryCredentials(), client: http)
        for invalid in ["ghp_fictional", token + "\r\nInjected: yes", "", "github_pat_"] {
            do { try await transport.connect(personalAccessToken: invalid); XCTFail("Invalid credential") }
            catch { XCTAssertEqual(error as? GitHubBackupError, .invalidCredential) }
        }
        let requests = await http.requests; XCTAssertTrue(requests.isEmpty)
    }
    func testSuccessfulConnectStoresOnlyRepositoryScopedCredential() async throws {
        let credentials = BackupMemoryCredentials(), http = BackupHTTPFixture([try metadata()])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: credentials, client: http)
        try await transport.connect(personalAccessToken: token)
        XCTAssertEqual(credentials.read(account: try repo().credentialAccount), Data(token.utf8))
        XCTAssertNil(credentials.read(account: "github-backup:another/repository"))
        let requests = await http.requests
        XCTAssertEqual(requests.first?.url?.host, "api.github.com")
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)")
        XCTAssertNil(requests.first?.httpBody)
        try await transport.disconnect(); XCTAssertNil(credentials.read(account: try repo().credentialAccount))
    }
    func testExpiredOrRevokedCredentialRequiresReconnectAndIsRemoved() async throws {
        let credentials = try storedCredentials(), http = BackupHTTPFixture([.init(status: 401, data: Data("untrusted raw error".utf8))])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: credentials, client: http)
        do { _ = try await transport.upload(archive(), versionID: versionID); XCTFail("Revoked") }
        catch { XCTAssertEqual(error as? GitHubBackupError, .authenticationRequired) }
        XCTAssertNil(credentials.read(account: try repo().credentialAccount))
    }
    func testRateLimitKeepsCredentialAndReturnsSafeFailure() async throws {
        let credentials = try storedCredentials(), http = BackupHTTPFixture([.init(status: 403, data: Data(), remainingRateLimit: "0")])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: credentials, client: http)
        do { _ = try await transport.upload(archive(), versionID: versionID); XCTFail("Rate limit") }
        catch { XCTAssertEqual(error as? GitHubBackupError, .rateLimited) }
        XCTAssertNotNil(credentials.read(account: try repo().credentialAccount))
    }
    func testInvalidArchiveNeverReachesNetwork() async throws {
        let http = BackupHTTPFixture([]), transport = GitHubBackupTransport(repository: try repo(), credentials: try storedCredentials(), client: http)
        do { _ = try await transport.upload(Data("not a ZIP".utf8), versionID: versionID); XCTFail("Corrupt archive") }
        catch { XCTAssertEqual(error as? PortableBackupError, .invalidArchive) }
        let requests = await http.requests; XCTAssertTrue(requests.isEmpty)
    }
    func testRepositoryCheckedAgainBeforeEveryUpload() async throws {
        let http = BackupHTTPFixture([try metadata(isPrivate: false)])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: try storedCredentials(), client: http)
        do { _ = try await transport.upload(archive(), versionID: versionID); XCTFail("Repository changed to public") }
        catch { XCTAssertEqual(error as? GitHubBackupError, .repositoryNotPrivate) }
        let requests = await http.requests; XCTAssertEqual(requests.count, 1)
    }
    func testManualVersionUploadIsSecretFreeAndNeverOverwritesExistingSHA() async throws {
        let data = try archive(), path = "backups/\(versionID.uuidString.lowercased()).zip"
        let result = try JSONSerialization.data(withJSONObject: ["content": ["path": path], "commit": ["sha": sha]])
        let http = BackupHTTPFixture([try metadata(), .init(status: 404, data: Data()), .init(status: 201, data: result)])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: try storedCredentials(), client: http)
        let version = try await transport.upload(data, versionID: versionID)
        XCTAssertEqual(version.commitSHA, sha); XCTAssertEqual(version.path, path); XCTAssertEqual(version.id, versionID)
        let requests = await http.requests; XCTAssertEqual(requests.map(\.httpMethod), ["GET", "GET", "PUT"])
        let body = try XCTUnwrap(requests.last?.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertNil(object["sha"])
        XCTAssertFalse(String(decoding: body, as: UTF8.self).contains(token))
        XCTAssertEqual(Data(base64Encoded: try XCTUnwrap(object["content"])), data)
    }
    func testLostResponseRetryAcknowledgesSameVersionWithoutSecondPut() async throws {
        let data = try archive(), commit = try JSONSerialization.data(withJSONObject: [["sha": sha]])
        let http = BackupHTTPFixture([try metadata(), .init(status: 200, data: data), .init(status: 200, data: commit)])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: try storedCredentials(), client: http)
        let version = try await transport.upload(data, versionID: versionID); XCTAssertEqual(version.commitSHA, sha)
        let requests = await http.requests; XCTAssertEqual(requests.map(\.httpMethod), ["GET", "GET", "GET"])
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "Accept"), "application/vnd.github.raw+json")
    }
    func testVersionCollisionNeverOverwritesDifferentBackup() async throws {
        let http = BackupHTTPFixture([try metadata(), .init(status: 200, data: Data("different bytes".utf8))])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: try storedCredentials(), client: http)
        do { _ = try await transport.upload(archive(), versionID: versionID); XCTFail("Version collision") }
        catch { XCTAssertEqual(error as? GitHubBackupError, .versionCollision) }
        let requests = await http.requests; XCTAssertFalse(requests.contains { $0.httpMethod == "PUT" })
    }
    func testPermissionFailureDoesNotDiscardValidCredential() async throws {
        let credentials = try storedCredentials(), http = BackupHTTPFixture([.init(status: 403, data: Data("raw provider error".utf8))])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: credentials, client: http)
        do { _ = try await transport.upload(archive(), versionID: versionID); XCTFail("Permissions") }
        catch { XCTAssertEqual(error as? GitHubBackupError, .insufficientPermissions) }
        XCTAssertNotNil(credentials.read(account: try repo().credentialAccount))
    }
    func testRepositoryCannotInjectHostPathOrQuery() throws {
        for value in ["..", ".", "reader/repo", "reader?token", "reader#fragment", "reader\\repo", "https://evil.test", ""] {
            XCTAssertThrowsError(try GitHubBackupRepository(owner: value, name: "backup"))
            XCTAssertThrowsError(try GitHubBackupRepository(owner: "reader", name: value))
        }
    }
    private func listingResponses(size: Int, truncated: Bool = false, mode: String = "100644") throws -> [GitHubBackupHTTPResponse] {
        [try metadata(),
         .init(status: 200, data: try JSONSerialization.data(withJSONObject: [["sha": sha]])),
         .init(status: 200, data: try JSONSerialization.data(withJSONObject: ["tree": ["sha": String(repeating: "b", count: 40)]])),
         .init(status: 200, data: try JSONSerialization.data(withJSONObject: ["truncated": truncated,
            "tree": [["path": "backups/\(versionID.uuidString.lowercased()).zip", "mode": mode, "type": "blob", "sha": sha, "size": size]]]))]
    }
    func testVersionHistoryAndDownloadUseOneImmutableSnapshot() async throws {
        let data = try archive()
        let http = BackupHTTPFixture(try listingResponses(size: data.count) + [metadata(), .init(status: 200, data: data)])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: try storedCredentials(), client: http)
        let versions = try await transport.versions(); XCTAssertEqual(versions.count, 1)
        XCTAssertEqual(versions[0].id, versionID); XCTAssertEqual(versions[0].snapshotCommitSHA, sha)
        let result = try await transport.download(versions[0]); XCTAssertEqual(result.manifest.entityCounts, ["books": 0])
        let requests = await http.requests
        XCTAssertEqual(requests.last?.url?.query, "ref=\(sha)")
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "Accept"), "application/vnd.github.raw+json")
    }
    func testTruncatedHistoryIsFailureRatherThanIncompleteSuccess() async throws {
        let http = BackupHTTPFixture(try listingResponses(size: 1, truncated: true))
        let transport = GitHubBackupTransport(repository: try repo(), credentials: try storedCredentials(), client: http)
        do { _ = try await transport.versions(); XCTFail("Partial history") }
        catch { XCTAssertEqual(error as? GitHubBackupError, .invalidResponse) }
    }
    func testRemoteSymlinkCannotMasqueradeAsBackup() async throws {
        let http = BackupHTTPFixture(try listingResponses(size: 1, mode: "120000"))
        let transport = GitHubBackupTransport(repository: try repo(), credentials: try storedCredentials(), client: http)
        do { _ = try await transport.versions(); XCTFail("Symlink") }
        catch { XCTAssertEqual(error as? GitHubBackupError, .invalidResponse) }
    }
    func testDownloadMustValidateBytesBeforePreview() async throws {
        let data = try archive()
        let corrupt = Data(repeating: 0, count: data.count)
        let http = BackupHTTPFixture(try listingResponses(size: data.count) + [metadata(), .init(status: 200, data: corrupt)])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: try storedCredentials(), client: http)
        let versions = try await transport.versions()
        do { _ = try await transport.download(versions[0]); XCTFail("Corrupt") }
        catch { XCTAssertEqual(error as? PortableBackupError, .invalidArchive) }
    }
    func testFailedCredentialReplacementPreservesPriorStoredCredential() async throws {
        let credentials = try storedCredentials(), http = BackupHTTPFixture([.init(status: 401, data: Data())])
        let transport = GitHubBackupTransport(repository: try repo(), credentials: credentials, client: http)
        do { try await transport.connect(personalAccessToken: "github_pat_fictionalInvalidReplacement"); XCTFail("Invalid replacement") }
        catch { XCTAssertEqual(error as? GitHubBackupError, .authenticationRequired) }
        XCTAssertTrue(credentials.read(account: try repo().credentialAccount) == Data(token.utf8))
    }
}
