import XCTest
import GRDB
import ReadingDomain
@testable import ReadingData

private enum LostAcknowledgement: Error { case offline }
private actor DurableReceiptFixture: SyncTransport {
    private(set) var received: [UUID] = []
    private(set) var applied = Set<UUID>()
    private var loseFirstResponse = true
    func send(_ mutation: MutationEnvelope) throws -> SyncResult {
        received.append(mutation.id); applied.insert(mutation.id)
        if loseFirstResponse { loseFirstResponse = false; throw LostAcknowledgement.offline }
        return .acknowledged(revision: 1)
    }
}
final class Phase9SyncDurabilityTests: XCTestCase {
    private func add(_ store: LocalStore) throws -> MutationEnvelope {
        let book = Book(ownerID: store.ownerID, title: "Durable", author: "Reader")
        let mutation = MutationEnvelope(ownerID: store.ownerID, entityID: book.id, expectedRevision: 0,
            generation: UUID(), kind: "book.create", payload: try JSONEncoder().encode(BookCreatePayload(title: book.title, author: book.author, wantsToRead: true)))
        try store.addBook(book, wantsToRead: true, mutation: mutation)
        return mutation
    }
    func testOutboxVersionPayloadIdentityAndGenerationSurviveRestart() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let owner = UUID(), store = try LocalStore(path: url.path, ownerID: owner), mutation = try add(store)
        // Simulate a newer queued command being opened by an older binary. It
        // must remain version 2 for the transport's closed version gate.
        try await store.queue.write { db in try db.execute(sql: "UPDATE outbox SET command_version=2 WHERE id=?", arguments: [mutation.id.uuidString]) }
        let reopened = try LocalStore(path: url.path, ownerID: owner)
        let pending = try await reopened.pending(ownerID: owner)
        XCTAssertEqual(pending.count, 1); XCTAssertEqual(pending[0].commandVersion, 2)
        XCTAssertEqual(pending[0].id, mutation.id); XCTAssertEqual(pending[0].payload, mutation.payload)
        XCTAssertEqual(pending[0].generation, mutation.generation); XCTAssertEqual(pending[0].expectedRevision, mutation.expectedRevision)
    }
    func testLostServerAcknowledgementThenRestartRetriesSameDurableMutation() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let owner = UUID(), store = try LocalStore(path: url.path, ownerID: owner), mutation = try add(store)
        let server = DurableReceiptFixture(), first = SyncCoordinator(outbox: store, transport: server)
        do { try await first.flush(ownerID: owner); XCTFail("Response was lost") } catch {}
        let retained = try await store.pending(ownerID: owner); XCTAssertEqual(retained.map(\.id), [mutation.id])
        let reopened = try LocalStore(path: url.path, ownerID: owner)
        try await SyncCoordinator(outbox: reopened, transport: server).flush(ownerID: owner)
        let remaining = try await reopened.pending(ownerID: owner), received = await server.received, applied = await server.applied
        XCTAssertTrue(remaining.isEmpty); XCTAssertEqual(received, [mutation.id, mutation.id]); XCTAssertEqual(applied.count, 1)
        XCTAssertEqual(try reopened.bookCount(), 1)
        let revision = try await reopened.queue.read { try Int.fetchOne($0, sql: "SELECT revision FROM books WHERE owner_id=? AND id=?", arguments: [owner.uuidString, mutation.entityID.uuidString]) }
        XCTAssertEqual(revision, 1)
    }
}
