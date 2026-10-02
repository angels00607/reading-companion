import XCTest
import ReadingData
import ReadingDomain

final class BooksAtomicTests: XCTestCase {
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
