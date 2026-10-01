import XCTest
import ReadingDomain
import GRDB
@testable import ReadingData

final class LocalStoreTests: XCTestCase {
    func testLegacyMigrationPreservesPageObservationAndJournalPayload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let owner = UUID()
        let queue = try DatabaseQueue(path: url.path)
        var migrator = DatabaseMigrator()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let schema = try String(contentsOf: root.appendingPathComponent("Sources/ReadingData/Resources/local_v1.sql"), encoding:.utf8)
        migrator.registerMigration("local_v1") { db in try db.execute(sql:schema) }
        try migrator.migrate(queue)
        try queue.write { db in
            try db.execute(sql:"INSERT INTO books(id,owner_id,title,author) VALUES('b',?,'Legacy','Author')",arguments:[owner.uuidString])
            try db.execute(sql:"INSERT INTO readings(id,owner_id,book_id,status,current_page,total_pages) VALUES('r',?,'b','read',187,450)",arguments:[owner.uuidString])
            try db.execute(sql:"INSERT INTO progress_observations VALUES(?,'o','r','m',100,187,'now',0)",arguments:[owner.uuidString])
            try db.execute(sql:"INSERT INTO journal_components VALUES(?,'j','r','book_review','copied','legacy','now')",arguments:[owner.uuidString])
        }
        let upgraded = try LocalStore(path:url.path,ownerID:owner)
        XCTAssertEqual(try upgraded.bookCount(),1)
        try queue.read { db in
            let reading = try XCTUnwrap(Row.fetchOne(db,sql:"SELECT * FROM readings WHERE id='r'"))
            let mode: String = reading["progress_mode"]
            let page: Int = reading["current_page"]
            let percentage: Double? = reading["progress_percentage"]
            XCTAssertEqual(mode,"page"); XCTAssertEqual(page,187); XCTAssertNil(percentage)
            XCTAssertEqual(try Int.fetchOne(db,sql:"SELECT new_page-previous_page FROM progress_observations"),87)
            XCTAssertEqual(try String.fetchOne(db,sql:"SELECT copied_payload FROM journal_components"),"legacy")
            try db.checkForeignKeys()
        }
    }
    func testAtomicOutboxRollbackAndAccountIsolation() async throws {
        let owner = UUID()
        let store = try LocalStore(path: ":memory:", ownerID: owner)
        let book = Book(ownerID: owner, title: "Test", author: "Author")
        let mutation = try MutationEnvelope(ownerID: owner, entityID: book.id, expectedRevision: 0,
            generation: UUID(), kind: "book.create", payload: JSONEncoder().encode(BookCreatePayload(title: book.title, author: book.author, wantsToRead: true)))
        try store.addBook(book, wantsToRead: true, mutation: mutation)
        XCTAssertEqual(try store.bookCount(), 1)
        let pending = try await store.pending(ownerID: owner)
        XCTAssertEqual(pending.map(\.id), [mutation.id])
        // Same mutation ID causes outbox failure; the newly inserted book must also roll back.
        let other = Book(ownerID: owner, title: "Other", author: "Author")
        let duplicate = try MutationEnvelope(id: mutation.id, ownerID: owner, entityID: other.id,
            expectedRevision: 0, generation: mutation.generation, kind: "book.create", payload: JSONEncoder().encode(BookCreatePayload(title: other.title, author: other.author, wantsToRead: false)))
        XCTAssertThrowsError(try store.addBook(other, wantsToRead: false, mutation: duplicate))
        XCTAssertEqual(try store.bookCount(), 1)
        do { _ = try await store.pending(ownerID: UUID()); XCTFail("Cross-account read accepted") } catch {}
        try await store.requireReview(id: mutation.id)
        let after = try await store.pending(ownerID: owner)
        XCTAssertTrue(after.isEmpty)
    }
    func testMigrationReopensExistingDatabase() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let owner = UUID()
        let store = try LocalStore(path: url.path, ownerID: owner)
        let book = Book(ownerID: owner, title: "Persisted", author: "Author")
        try store.addBook(book, wantsToRead: true, mutation: MutationEnvelope(
            ownerID: owner, entityID: book.id, expectedRevision: 0,
            generation: UUID(), kind: "book.create", payload: JSONEncoder().encode(BookCreatePayload(title: book.title, author: book.author, wantsToRead: true))))
        let reopened = try LocalStore(path: url.path, ownerID: owner)
        XCTAssertEqual(try reopened.bookCount(), 1)
    }
}
