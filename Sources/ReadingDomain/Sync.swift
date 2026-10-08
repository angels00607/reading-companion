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
                generation: UUID, commandVersion: Int = 1, kind: String, payload: Data) {
        self.id = id; self.ownerID = ownerID; self.entityID = entityID
        self.expectedRevision = expectedRevision; self.generation = generation
        self.commandVersion = commandVersion; self.kind = kind; self.payload = payload
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
public struct RemoteChange:Equatable,Sendable {
    public let sequence:Int64;public let mutationID:UUID;public let entityID:UUID
    public let revision:Int;public let generation:UUID;public let kind:String;public let payload:Data;public let deletedAt:String?
    public init(sequence:Int64,mutationID:UUID,entityID:UUID,revision:Int,generation:UUID,kind:String,payload:Data,deletedAt:String?=nil){self.sequence=sequence;self.mutationID=mutationID;self.entityID=entityID;self.revision=revision;self.generation=generation;self.kind=kind;self.payload=payload;self.deletedAt=deletedAt}
}
public protocol SyncPullTransport:Sendable { func changes(after:Int64,limit:Int) async throws->[RemoteChange] }
public protocol SyncReplicaRepository:OutboxRepository {
    func pullCursor(ownerID:UUID) async throws->Int64
    func applyRemote(_ changes:[RemoteChange],ownerID:UUID) async throws
}
public protocol OutboxRepository: Sendable {
    func pending(ownerID: UUID) async throws -> [MutationEnvelope]
    func acknowledge(id: UUID, revision: Int) async throws
    func requireReview(id: UUID) async throws
    func recordAttemptFailure(id: UUID) async throws
    func requireReview(id:UUID,serverRevision:Int?,staleGeneration:Bool) async throws
}
public extension OutboxRepository {
    func recordAttemptFailure(id: UUID) async throws {}
    func requireReview(id:UUID,serverRevision:Int?,staleGeneration:Bool) async throws { try await requireReview(id:id) }
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
            let result: SyncResult
            do { result = try await transport.send(mutation) }
            catch { try await outbox.recordAttemptFailure(id:mutation.id); throw error }
            switch result {
            case .acknowledged(let revision): try await outbox.acknowledge(id: mutation.id, revision: revision)
            case .conflict(let revision):
                try await outbox.requireReview(id:mutation.id,serverRevision:revision,staleGeneration:false)
                return // Do not send dependent commands past an unresolved conflict.
            case .staleGeneration:
                try await outbox.requireReview(id:mutation.id,serverRevision:nil,staleGeneration:true)
                return // Do not send dependent commands past an unresolved conflict.
            }
        }
        // A transport failure leaves the durable mutation untouched for a later retry.
    }
}
public actor FullSyncCoordinator {
    private let replica:any SyncReplicaRepository;private let transport:any SyncTransport & SyncPullTransport
    public init(replica:any SyncReplicaRepository,transport:any SyncTransport & SyncPullTransport){self.replica=replica;self.transport=transport}
    public func synchronize(ownerID:UUID) async throws {
        try await SyncCoordinator(outbox:replica,transport:transport).flush(ownerID:ownerID)
        while true {
            let cursor=try await replica.pullCursor(ownerID:ownerID),values=try await transport.changes(after:cursor,limit:500)
            guard !values.isEmpty else{return};try await replica.applyRemote(values,ownerID:ownerID)
            if values.count<500{return}
        }
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
