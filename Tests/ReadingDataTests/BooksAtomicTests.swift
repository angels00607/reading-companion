import XCTest
import ReadingData
import ReadingDomain
import GRDB

final class BooksAtomicTests: XCTestCase {
    func testCorrectionsDuringExternalAddHaveUserProvenance() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let s = try LocalStore(path: path, ownerID: UUID())
        let work = WorkCandidate(provider: "external", reference: "work", title: "Supplied", author: "Author")
        let id = try s.addWithIntent(work: work, edition: nil, choice: .review, intent: .toRead, manualValues: [.title:"User corrected"])
        XCTAssertEqual(try s.record(id: id).book.title,"User corrected")
        let db = try DatabaseQueue(path: path)
        try await db.read { db in
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT source FROM field_provenance WHERE entity_id=? AND field='title'", arguments: [id.uuidString]), "manual")
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT user_overridden FROM field_provenance WHERE entity_id=? AND field='title'", arguments: [id.uuidString]), 1)
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT source FROM field_provenance WHERE entity_id=? AND field='author'", arguments: [id.uuidString]), "external")
        }
    }
    func testSlightlyDifferentMetadataNeedsReviewWithoutAutomaticMerge() throws {
        let s = try LocalStore(path: ":memory:", ownerID: UUID())
        _ = try s.add(work: WorkCandidate(provider: "one", reference: "one", title: "Emma", author: "Jane Austen"))
        XCTAssertThrowsError(try s.add(work: WorkCandidate(provider: "two", reference: "two", title: "Emma: Illustrated Edition", author: "Austen, Jane")))
        XCTAssertEqual(try s.bookCount(),1)
    }
    func testCombinedFiltersAndUnknownPagesLast() throws {
        let s = try LocalStore(path: ":memory:", ownerID: UUID())
        let work = WorkCandidate(provider: "manual", reference: "one", title: "A known", author: "Author")
        let id = try s.addWithIntent(work: work, edition: EditionCandidate(provider: "manual", reference: "edition", pageCount: 300), choice: .review, intent: .alreadyRead(date: try ReadingDate(year: 2026, month: 10, day: 2), rating: .stars(5)), manualValues: [.genreSuggestion:"Fantasy",.series:"A series"])
        _ = try s.add(work: WorkCandidate(provider: "manual", reference: "two", title: "Z unknown", author: "Author"))
        XCTAssertEqual(try s.library(sort: .pagesDescending).last?.book.title,"Z unknown")
        var f = LibraryFilters(); f.year = 2026; f.rating = 5; f.genre = "Fantasy"; f.inSeries = true
        XCTAssertEqual(try s.library(view: .read, filters: f).map(\.id),[id])
        f.genre = "Other"; XCTAssertTrue(try s.library(view: .read, filters: f).isEmpty)
        let reread = try s.start(bookID: id, editionID: nil, date: nil)
        try s.editReading(readingID: reread, start: nil, finish: nil, rating: .unknown, genre: "Other", format: nil, revision: 0)
        f.year = nil; f.rating = nil
        XCTAssertTrue(try s.library(view: .read, filters: f).isEmpty, "Read filters must match a completed reading, not an active reread")
    }
    func testAddIntentRollbackAndManualGenre() throws {
        let s = try LocalStore(path: ":memory:", ownerID: UUID())
        let work = WorkCandidate(provider: "manual", reference: "one", title: "Manual", author: "Author")
        let id = try s.addWithIntent(work: work, edition: nil, choice: .review, intent: .currentlyReading(mode: .page, date: nil), manualValues: [.genreSuggestion:"Fantasy"])
        XCTAssertEqual(try s.record(id: id).active?.primaryGenre,"Fantasy")
        XCTAssertThrowsError(try s.addWithIntent(work: work, edition: nil, choice: .review, intent: .currentlyReading(mode: .page, date: nil), manualValues: [.title:"Should roll back"]))
        XCTAssertEqual(try s.record(id: id).book.title,"Manual")
        XCTAssertEqual(try s.record(id: id).readings.count,1)
    }
    func testCompositeBookInfoRollbackAndCoverRemoval() throws {
        let s = try LocalStore(path: ":memory:", ownerID: UUID())
        let work = WorkCandidate(provider: "fixture", reference: "one", title: "Original", author: "Author", coverReference: "https://example.org/provider.png")
        let id = try s.add(work: work)
        let invalid = Edition(bookID: id, pageCount: -1)
        XCTAssertThrowsError(try s.editInfo(bookID: id, values: [.title:"Not committed"], edition: invalid, revision: 0))
        XCTAssertEqual(try s.record(id: id).book.title,"Original")
        try s.editInfo(bookID: id, values: [.cover:""], edition: nil, revision: 0)
        XCTAssertEqual(try s.record(id: id).coverReference,"")
        try s.reviewProvider(bookID: id, work: work)
        XCTAssertEqual(try s.record(id: id).coverReference,"")
    }
    func testISBNReuseRequiresExplicitWorkDecisionThenReusesEdition() throws {
        let s = try LocalStore(path: ":memory:", ownerID: UUID())
        let first = WorkCandidate(provider: "one", reference: "work", title: "Book", author: "Author")
        let e = EditionCandidate(provider: "one", reference: "edition", isbn13: "9780000000002", pageCount: 400)
        let id = try s.add(work: first, edition: e)
        let other = WorkCandidate(provider: "two", reference: "other-work", title: "Other spelling", author: "Author")
        let otherEdition = EditionCandidate(provider: "two", reference: "other-edition", isbn13: "9780000000002", pageCount: 500)
        XCTAssertThrowsError(try s.add(work: other, edition: otherEdition))
        XCTAssertEqual(try s.add(work: other, edition: otherEdition, choice: .reuse(id)), id)
        XCTAssertEqual(try s.record(id: id).editions.count,1)
        XCTAssertEqual(try s.record(id: id).editions.first?.pageCount,400)
    }
}
