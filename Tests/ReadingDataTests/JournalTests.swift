import XCTest
import ReadingData
import ReadingDomain

final class JournalTests: XCTestCase {
    private func completedStore(path: String = ":memory:") throws -> (LocalStore, UUID, UUID) {
        let store = try LocalStore(path: path, ownerID: UUID())
        let book = try store.add(work: WorkCandidate(provider: "fixture", reference: UUID().uuidString, title: "A Long Journal Title", author: "Author"))
        let reading = try store.start(bookID: book, editionID: nil, date: try ReadingDate(year: 2026, month: 1, day: 1))
        try store.finish(readingID: reading, confirmed: true, date: try ReadingDate(year: 2026, month: 1, day: 3), revision: 0)
        return (store, book, reading)
    }
    func testFinishCreatesOnePendingInboxEntryAndRetryDoesNotDuplicate() throws {
        let (store, _, reading) = try completedStore()
        XCTAssertEqual(try store.journalInbox().count, 1)
        XCTAssertEqual(try store.journalEntry(readingID: reading).components.count, JournalComponent.allCases.count)
        XCTAssertThrowsError(try store.finish(readingID: reading, confirmed: true, date: nil, revision: 0))
        XCTAssertEqual(try store.journalInbox().count, 1)
    }
    func testDNFAndHistoricalCompletionDoNotEnterInbox() throws {
        let store = try LocalStore(path: ":memory:", ownerID: UUID())
        let historicalBook = try store.add(work: WorkCandidate(provider: "fixture", reference: "historical", title: "Historical", author: "Author"))
        _ = try store.recordCompleted(bookID: historicalBook, editionID: nil, date: nil, rating: .noRating)
        let dnfBook = try store.add(work: WorkCandidate(provider: "fixture", reference: "dnf", title: "DNF", author: "Author"))
        let reading = try store.start(bookID: dnfBook, editionID: nil, date: nil)
        try store.markDNF(readingID: reading, revision: 0)
        XCTAssertTrue(try store.journalInbox().isEmpty)
    }
    func testReviewBecomesReadyAndCopiedEditCreatesCorrection() throws {
        let (store, _, reading) = try completedStore()
        let draft = BookReviewDraft(summary: "My own summary", pageCount: 320, rating: .stars(5), format: .hardcover, start: nil, finish: nil)
        try store.saveBookReview(readingID: reading, draft: draft)
        XCTAssertEqual(try store.readyForSession().map(\.reading.id), [reading])
        try store.markBookReviewCopied(readingID: reading)
        XCTAssertEqual(try store.journalUsage().bookReviews, 1)
        try store.saveBookReview(readingID: reading, draft: BookReviewDraft(summary: "Corrected summary", pageCount: 320, rating: .stars(5), format: .hardcover, start: nil, finish: nil))
        let correction = try XCTUnwrap(store.corrections().first)
        XCTAssertEqual(correction.field, "Summary")
        try store.resolveCorrection(id: correction.id)
        XCTAssertTrue(try store.corrections().first?.resolved == true)
    }
    func testFavoritesQuotesAndExplicitNoQuoteRemainSeparate() throws {
        let (store, book, reading) = try completedStore()
        try store.setFavorite(bookID: book, decision: .none)
        XCTAssertEqual(try store.favoriteDecision(bookID: book), .none)
        let physical = JournalQuote(bookID: book, readingID: reading, text: "First", source: "p. 4", includeInJournal: true)
        try store.saveQuote(physical)
        try store.saveQuote(JournalQuote(bookID: book, readingID: reading, text: "Second", source: nil, includeInJournal: false))
        XCTAssertEqual(try store.quotes(bookID: book).count, 2)
        try store.markQuoteCopied(id: physical.id)
        XCTAssertNotNil(try store.quotes(bookID: book).first(where: { $0.id == physical.id })?.copiedAt)
        try store.setNoQuote(readingID: reading, value: true)
        XCTAssertEqual(try store.journalEntry(readingID: reading).components[.quote], .none)
    }
}
