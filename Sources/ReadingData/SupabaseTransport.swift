import Foundation
import ReadingDomain

/// Receipt-backed Phase 9 command transport. Server-side RLS and the RPC retain
/// ownership, generation, revision and idempotency enforcement.
public struct SupabaseTransport: SyncTransport {
    private let configuration: AppConfiguration
    private let session: any AccountSession
    public init(configuration: AppConfiguration, session: any AccountSession) {
        self.configuration = configuration; self.session = session
    }
    public func send(_ mutation: MutationEnvelope) async throws -> SyncResult {
        guard try await session.ownerID == mutation.ownerID,
              mutation.commandVersion == 1 else { throw TransportError.unsupportedCommand }
        guard mutation.payload.count <= 8 * 1024 * 1024,
              (try? JSONSerialization.jsonObject(with:mutation.payload)) != nil,
              Self.supportedPrefixes.contains(where:mutation.kind.hasPrefix) else { throw TransportError.unsupportedCommand }
        let body = RPCBody(p_mutation_id: mutation.id, p_entity_id: mutation.entityID,
            p_expected_revision: mutation.expectedRevision, p_generation: mutation.generation,
            p_command_version: mutation.commandVersion, p_kind:mutation.kind,
            p_payload_base64:mutation.payload.base64EncodedString())
        var request = URLRequest(url: configuration.supabaseURL.appendingPathComponent("rest/v1/rpc/apply_sync_command"))
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer " + (try await session.accessToken()), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TransportError.requestFailed // Never log raw server response or credentials.
        }
        let result = try JSONDecoder().decode(RPCResult.self, from: data)
        switch result.status {
        case "acknowledged":
            guard let revision = result.revision else { throw TransportError.invalidResponse }
            return .acknowledged(revision: revision)
        case "conflict":
            guard let revision = result.revision else { throw TransportError.invalidResponse }
            return .conflict(serverRevision: revision)
        case "stale_generation": return .staleGeneration
        default: throw TransportError.invalidResponse
        }
    }
    private static let supportedPrefixes = ["book.","catalog.","library.","edition.","reading.","journal.",
        "series.","challenge.","stats.","profile.","quest.","cosmetic.","gamification.","import."]
}
public struct BookCreatePayload: Codable, Sendable {
    public let title: String
    public let author: String
    public let wantsToRead: Bool
    public init(title: String, author: String, wantsToRead: Bool) {
        self.title = title; self.author = author; self.wantsToRead = wantsToRead
    }
}
private struct RPCBody: Encodable {
    let p_mutation_id: UUID
    let p_entity_id: UUID
    let p_expected_revision: Int
    let p_generation: UUID
    let p_command_version: Int
    let p_kind: String
    let p_payload_base64: String
}
private struct RPCResult: Decodable { let status: String; let revision: Int? }
public enum TransportError: Error { case unsupportedCommand, requestFailed, invalidResponse }
