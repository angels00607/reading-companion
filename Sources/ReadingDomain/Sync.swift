import Foundation

public struct MutationEnvelope: Codable, Equatable, Sendable {
    public let id: UUID
    public let ownerID: UUID
    public let entityID: UUID
    public let expectedRevision: Int
    public let generation: UUID
    public let commandVersion: Int
    public let kind: String
    public let payload: Data
    public init(id: UUID = UUID(), ownerID: UUID, entityID: UUID, expectedRevision: Int,
                generation: UUID, kind: String, payload: Data) {
        self.id = id; self.ownerID = ownerID; self.entityID = entityID
        self.expectedRevision = expectedRevision; self.generation = generation
        commandVersion = 1; self.kind = kind; self.payload = payload
    }
}
public enum SyncResult: Sendable {
    case acknowledged(revision: Int)
    case conflict(serverRevision: Int)
    case staleGeneration
}
public protocol SyncTransport: Sendable {
    func send(_ mutation: MutationEnvelope) async throws -> SyncResult
}
public protocol OutboxRepository: Sendable {
    func pending(ownerID: UUID) async throws -> [MutationEnvelope]
    func acknowledge(id: UUID, revision: Int) async throws
    func requireReview(id: UUID) async throws
}
public actor SyncCoordinator {
    private let outbox: any OutboxRepository
    private let transport: any SyncTransport
    private var running = false
    public init(outbox: any OutboxRepository, transport: any SyncTransport) {
        self.outbox = outbox; self.transport = transport
    }
    public func flush(ownerID: UUID) async throws {
        guard !running else { return }
        running = true
        defer { running = false }
        for mutation in try await outbox.pending(ownerID: ownerID) {
            switch try await transport.send(mutation) {
            case .acknowledged(let revision): try await outbox.acknowledge(id: mutation.id, revision: revision)
            case .conflict, .staleGeneration:
                try await outbox.requireReview(id: mutation.id)
                return // Do not send dependent commands past an unresolved conflict.
            }
        }
        // A transport failure leaves the durable mutation untouched for a later retry.
    }
}
public protocol BookMetadataProvider: Sendable {
    var key: String { get }
    func search(query: String, preferredLanguage: String) async throws -> [MetadataCandidate]
}
public struct MetadataCandidate: Sendable {
    public let providerID: String
    public let title: String?
    public let author: String?
    public let language: String?
    public let pageCount: Int?
    public let provenance: Provenance
    public init(providerID: String, title: String?, author: String?, language: String?, pageCount: Int?, provenance: Provenance) {
        self.providerID = providerID; self.title = title; self.author = author; self.language = language; self.pageCount = pageCount; self.provenance = provenance
    }
    // Journal Format is intentionally absent from external contracts.
}
public protocol SummaryAssistant: Sendable {
    func draft(bookID: UUID, approvedContext: String) async throws -> String
}
