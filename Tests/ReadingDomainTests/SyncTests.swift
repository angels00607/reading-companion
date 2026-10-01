import XCTest
@testable import ReadingDomain

private actor MemoryOutbox: OutboxRepository {
    var mutations: [MutationEnvelope]
    var reviewed = Set<UUID>()
    init(_ mutations: [MutationEnvelope]) { self.mutations = mutations }
    func pending(ownerID: UUID) -> [MutationEnvelope] {
        Array(mutations.filter { $0.ownerID == ownerID }.prefix { !reviewed.contains($0.id) })
    }
    func acknowledge(id: UUID, revision: Int) { mutations.removeAll { $0.id == id } }
    func requireReview(id: UUID) { reviewed.insert(id) }
}
private actor FlakyTransport: SyncTransport {
    var ids: [UUID] = []
    var fail = true
    func send(_ mutation: MutationEnvelope) throws -> SyncResult {
        ids.append(mutation.id)
        if fail { fail = false; throw TransportErrorForTest.offline }
        return .acknowledged(revision: 1)
    }
}
private enum TransportErrorForTest: Error { case offline }
private actor ConflictTransport: SyncTransport {
    var ids: [UUID] = []
    func send(_ mutation: MutationEnvelope) -> SyncResult {
        ids.append(mutation.id); return .conflict(serverRevision: 1)
    }
}
final class SyncTests: XCTestCase {
    func testRetryUsesSameIDAndKeepsMutationUntilAcknowledged() async throws {
        let owner = UUID()
        let mutation = MutationEnvelope(ownerID: owner, entityID: UUID(), expectedRevision: 0,
            generation: UUID(), kind: "book.create", payload: Data())
        let outbox = MemoryOutbox([mutation])
        let transport = FlakyTransport()
        let coordinator = SyncCoordinator(outbox: outbox, transport: transport)
        do { try await coordinator.flush(ownerID: owner); XCTFail("Expected offline") } catch {}
        let retained = await outbox.pending(ownerID: owner)
        XCTAssertEqual(retained.count, 1)
        try await coordinator.flush(ownerID: owner)
        let ids = await transport.ids
        let remaining = await outbox.pending(ownerID: owner)
        XCTAssertEqual(ids, [mutation.id,mutation.id]); XCTAssertTrue(remaining.isEmpty)
    }
    func testConflictBlocksSubsequentCommandsAcrossFlushes() async throws {
        let owner = UUID(), generation = UUID()
        let mutations = (0..<2).map { _ in MutationEnvelope(ownerID: owner, entityID: UUID(),
            expectedRevision: 0, generation: generation, kind: "book.create", payload: Data()) }
        let outbox = MemoryOutbox(mutations), transport = ConflictTransport()
        let coordinator = SyncCoordinator(outbox: outbox, transport: transport)
        try await coordinator.flush(ownerID: owner)
        try await coordinator.flush(ownerID: owner)
        let ids = await transport.ids
        XCTAssertEqual(ids, [mutations[0].id])
    }
}
