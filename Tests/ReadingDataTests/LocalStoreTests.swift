import XCTest
import ReadingDomain
@testable import ReadingData

final class LocalStoreTests: XCTestCase {
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

