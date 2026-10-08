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
        let attempts = try await store.queue.read { try Int.fetchOne($0,sql:"SELECT attempt_count FROM outbox WHERE id=?",arguments:[mutation.id.uuidString]) }
        XCTAssertEqual(attempts,1)
        let reopened = try LocalStore(path: url.path, ownerID: owner)
        try await SyncCoordinator(outbox: reopened, transport: server).flush(ownerID: owner)
        let remaining = try await reopened.pending(ownerID: owner), received = await server.received, applied = await server.applied
        XCTAssertTrue(remaining.isEmpty); XCTAssertEqual(received, [mutation.id, mutation.id]); XCTAssertEqual(applied.count, 1)
        XCTAssertEqual(try reopened.bookCount(), 1)
        let revision = try await reopened.queue.read { try Int.fetchOne($0, sql: "SELECT revision FROM books WHERE owner_id=? AND id=?", arguments: [owner.uuidString, mutation.entityID.uuidString]) }
        XCTAssertEqual(revision, 1)
        let receipts = try await reopened.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM sync_receipts WHERE mutation_id=?",arguments:[mutation.id.uuidString]) }
        XCTAssertEqual(receipts,1)
    }

    func testServerRevisionConflictIsDurableAndPreservesProgressObservation() async throws {
        actor Conflict:SyncTransport { func send(_ mutation:MutationEnvelope)->SyncResult{.conflict(serverRevision:7)} }
        let store=try LocalStore(path:":memory:",ownerID:UUID())
        let book=try store.add(work:.init(provider:"manual",reference:"conflict",title:"Conflict",author:"Reader"),choice:.addAnyway)
        let reading=try store.start(bookID:book,editionID:nil,date:nil)
        let observation=UUID();_ = try store.update(readingID:reading,value:.pages(current:40),revision:0,observationID:observation)
        let queued=try await store.pending(ownerID:store.ownerID)
        for mutation in queued where mutation.id != observation { try await store.acknowledge(id:mutation.id,revision:1) }
        try await SyncCoordinator(outbox:store,transport:Conflict()).flush(ownerID:store.ownerID)
        let evidence=try await store.queue.read { db -> (Int,Int?,String,String) in
            let row=try Row.fetchOne(db,sql:"SELECT server_revision,reason FROM sync_conflicts ORDER BY created_at LIMIT 1")!
            return (try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM progress_observations WHERE id=?",arguments:[observation.uuidString]) ?? 0,row["server_revision"],row["reason"],try String.fetchOne(db,sql:"SELECT state FROM outbox ORDER BY ordinal LIMIT 1")!)
        }
        XCTAssertEqual(evidence.0,1);XCTAssertEqual(evidence.1,7);XCTAssertEqual(evidence.2,"revision");XCTAssertEqual(evidence.3,"review")
    }

    func testQuoteDeletionCreatesDurableTombstoneAndOutboxCommand() throws {
        let store=try LocalStore(path:":memory:",ownerID:UUID())
        let book=try store.add(work:.init(provider:"manual",reference:"quote-delete",title:"Quote",author:"Reader"),choice:.addAnyway)
        let quote=JournalQuote(bookID:book,readingID:nil,text:"Keep deletion evidence",source:nil,includeInJournal:false)
        try store.saveQuote(quote);try store.deleteQuote(id:quote.id)
        let values=try store.queue.read { db in (
            try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM quotes WHERE id=?",arguments:[quote.id.uuidString]) ?? -1,
            try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM sync_tombstones WHERE entity_type='quote' AND entity_id=?",arguments:[quote.id.uuidString]) ?? -1,
            try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM outbox WHERE kind='journal.quote.delete' AND entity_id=?",arguments:[quote.id.uuidString]) ?? -1) }
        XCTAssertEqual(values.0,0);XCTAssertEqual(values.1,1);XCTAssertEqual(values.2,1)
    }

    func testRemotePullIsOrderedIdempotentAndTombstoneWinsWithoutLocalPendingWork() async throws {
        let store=try LocalStore(path:":memory:",ownerID:UUID()),generation=UUID(),book=UUID(),quote=UUID()
        let create=RemoteChange(sequence:1,mutationID:UUID(),entityID:book,revision:1,generation:generation,kind:"book.create",payload:try JSONEncoder().encode(BookCreatePayload(title:"Cloud Book",author:"Reader",wantsToRead:true)))
        try await store.applyRemote([create,create],ownerID:store.ownerID)
        XCTAssertEqual(try store.bookCount(),1);let firstCursor=try await store.pullCursor(ownerID:store.ownerID);XCTAssertEqual(firstCursor,1)
        try await store.queue.write { db in try db.execute(sql:"INSERT INTO quotes(owner_id,id,book_id,quote_text,include_in_journal) VALUES(?,?,?,'Remote deletion',0)",arguments:[store.ownerID.uuidString,quote.uuidString,book.uuidString]) }
        let payload=try JSONSerialization.data(withJSONObject:["entityType":"quote","entityID":quote.uuidString,"deletedAt":"2026-10-08T00:00:00Z"])
        let deletion=RemoteChange(sequence:2,mutationID:UUID(),entityID:quote,revision:1,generation:generation,kind:"journal.quote.delete",payload:payload,deletedAt:"2026-10-08T00:00:00Z")
        try await store.applyRemote([deletion],ownerID:store.ownerID)
        let counts=try await store.queue.read { db in (try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM quotes WHERE id=?",arguments:[quote.uuidString])!,try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM sync_tombstones WHERE entity_id=?",arguments:[quote.uuidString])!) }
        let secondCursor=try await store.pullCursor(ownerID:store.ownerID)
        XCTAssertEqual(counts.0,0);XCTAssertEqual(counts.1,1);XCTAssertEqual(secondCursor,2)
    }
}
