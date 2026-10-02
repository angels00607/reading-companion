import XCTest
import ReadingDomain
import ReadingData
import GRDB

final class BooksCoreTests: XCTestCase {
    private func store() throws -> LocalStore { try LocalStore(path: ":memory:", ownerID: UUID()) }
    private var work: WorkCandidate { WorkCandidate(provider: "fixture", reference: "work", title: "Book", author: "Author", coverReference: "https://example.org/cover.png") }
    private var edition: EditionCandidate { EditionCandidate(provider: "fixture", reference: "en-edition", language: "en", isbn13: "9780000000002", pageCount: 400) }
    func testOfficialAcceptanceFlowAndRereadIdentity() throws {
        let s = try store()
        let id = try s.add(work: work, edition: edition)
        XCTAssertEqual(try s.library(query: "Book").map(\.id), [id])
        var book = try s.record(id: id)
        XCTAssertTrue(book.readings.isEmpty); XCTAssertTrue(book.wantsToRead)
        let readingID = try s.start(bookID: id, editionID: book.editions.first?.id, date: nil)
        XCTAssertNil(try s.record(id: id).active?.journalFormat)
        _ = try s.update(readingID: readingID, value: .pages(current: 183, total: 400), revision: 0)
        let update = try s.update(readingID: readingID, value: .pages(current: 257, total: 400), revision: 1)
        guard case .applied(let observation) = update else { return XCTFail("Unexpected conflict") }
        XCTAssertEqual(observation.genuinePageDelta, 74)
        _ = try s.update(readingID: readingID, value: .pages(current: 400, total: 400), revision: 2)
        XCTAssertEqual(try s.record(id: id).active?.status, .currentlyReading)
        XCTAssertThrowsError(try s.finish(readingID: readingID, confirmed: false, date: nil, revision: 3))
        XCTAssertTrue(try s.library(view: .read).isEmpty)
        try s.finish(readingID: readingID, confirmed: true, date: nil, revision: 3)
        XCTAssertEqual(try s.library(view: .read).map(\.id), [id])
        book = try s.record(id: id)
        let reread = try s.start(bookID: id, editionID: book.editions.first?.id, date: nil)
        XCTAssertNotEqual(readingID, reread); XCTAssertEqual(try s.bookCount(), 1)
        XCTAssertEqual(try s.record(id: id).readings.count, 2)
        XCTAssertEqual(try s.record(id: id).readings.last?.status, .read)
    }
    func testNoFormatInferenceFromAnyProviderEditionOrReread() throws {
        let s = try store(), id = try s.add(work: work, edition: edition)
        let rid = try s.start(bookID: id, editionID: s.record(id: id).editions.first?.id, date: nil)
        XCTAssertNil(try s.record(id: id).active?.journalFormat)
        try s.editReading(readingID: rid, start: nil, finish: nil, rating: .unknown, genre: nil, format: .audiobook, revision: 0)
        try s.finish(readingID: rid, confirmed: true, date: nil, revision: 1)
        _ = try s.start(bookID: id, editionID: nil, mode: .percentage, date: nil)
        XCTAssertNil(try s.record(id: id).active?.journalFormat)
        XCTAssertNil(try s.record(id: id).active?.progress.currentPage)
    }
    func testDNFPreservesUnitAndNoDownstreamWrites() async throws {
        let s = try store(), id = try s.add(work: work)
        let rid = try s.start(bookID: id, editionID: nil, mode: .percentage, date: nil)
        _ = try s.update(readingID: rid, value: .percentage(57.5), revision: 0)
        try s.markDNF(readingID: rid, revision: 1)
        let reading = try XCTUnwrap(s.record(id: id).latest)
        XCTAssertEqual(reading.progress.percentage, 57.5); XCTAssertNil(reading.progress.currentPage)
        XCTAssertNil(ProgressRules.pagesReadFromObservations(reading)); XCTAssertFalse(ReadingRules.includedInCompletedStats(reading))
        XCTAssertFalse(JournalRules.mayGenerateCompletionWork(status: .dnf, origin: .user))
        XCTAssertTrue(try s.library(view: .read).isEmpty)
        let outbox = try await s.pending(ownerID: s.ownerID)
        XCTAssertFalse(outbox.contains { $0.kind.hasPrefix("journal") || $0.kind.hasPrefix("xp") || $0.kind.hasPrefix("challenge") })
        try s.resume(readingID: rid, revision: 2)
        XCTAssertEqual(try s.record(id: id).active?.progress.percentage, 57.5)
    }
    func testUnknownPagesAndManualFinishWithNoPositionOrTotal() throws {
        let s = try store(), id = try s.add(work: work)
        let rid = try s.start(bookID: id, editionID: nil, mode: .percentage, date: nil)
        XCTAssertNil(try s.record(id: id).active?.progress.percentage)
        try s.finish(readingID: rid, confirmed: true, date: nil, revision: 0)
        let reading = try XCTUnwrap(s.record(id: id).latest)
        XCTAssertNil(reading.progress.currentPage); XCTAssertNil(reading.progress.totalPages)
        XCTAssertNil(ProgressRules.pagesReadFromObservations(reading))
        let historical = try s.recordCompleted(bookID: id, editionID: nil, date: nil, rating: .noRating)
        XCTAssertNotEqual(historical, rid)
        XCTAssertNil(try s.record(id: id).latest?.progress.currentPage)
    }
    func testFractionalPercentageAnd100NeverAutoFinish() throws {
        let s = try store(), id = try s.add(work: work, edition: edition)
        let rid = try s.start(bookID: id, editionID: nil, mode: .percentage, date: nil)
        _ = try s.update(readingID: rid, value: .percentage(99.25), revision: 0)
        _ = try s.update(readingID: rid, value: .percentage(100), revision: 1)
        let reading = try XCTUnwrap(s.record(id: id).active)
        XCTAssertEqual(reading.status, .currentlyReading)
        XCTAssertNil(ProgressRules.pagesReadFromObservations(reading))
        XCTAssertTrue(reading.progressObservations.allSatisfy { $0.value.currentPage == nil && $0.value.totalPages == nil })
        XCTAssertThrowsError(try ReadingProgress.percentage(.infinity)); XCTAssertThrowsError(try ReadingProgress.percentage(-0.1)); XCTAssertThrowsError(try ReadingProgress.percentage(100.1))
    }
    func testProviderUserCoverAndGenrePriorityAndRejectedFingerprint() throws {
        let s = try store(), id = try s.add(work: work)
        try s.edit(bookID: id, values: [.title:"Corrected",.cover:"https://example.org/user.png"], revision: 0)
        let rid = try s.start(bookID: id, editionID: nil, date: nil)
        try s.editReading(readingID: rid, start: nil, finish: nil, rating: .unknown, genre: "Fantasy", format: nil, revision: 0)
        var fresh = work; fresh.title = "External correction"; fresh.coverReference = "https://example.org/provider.png"
        try s.reviewProvider(bookID: id, work: fresh)
        XCTAssertEqual(try s.record(id: id).book.title, "Corrected")
        XCTAssertEqual(try s.record(id: id).coverReference, "https://example.org/user.png")
        XCTAssertEqual(try s.record(id: id).active?.primaryGenre, "Fantasy")
        let proposals = try s.proposals(bookID: id)
        XCTAssertEqual(proposals.count, 2)
        for proposal in proposals { try s.decide(proposalID: proposal.id, accept: false) }
        try s.reviewProvider(bookID: id, work: fresh)
        XCTAssertTrue(try s.proposals(bookID: id).isEmpty)
        fresh.title = "New evidence"; try s.reviewProvider(bookID: id, work: fresh)
        XCTAssertEqual(try s.proposals(bookID: id).count, 1)
    }
    func testDuplicatesReuseWorkNewEditionAndExplicitUncertainResolution() throws {
        let s = try store(), id = try s.add(work: work, edition: edition)
        let fr = EditionCandidate(provider: "fixture", reference: "fr", language: "fr", pageCount: 420)
        XCTAssertEqual(try s.add(work: work, edition: fr), id)
        XCTAssertEqual(try s.bookCount(), 1); XCTAssertEqual(try s.record(id: id).editions.count, 2)
        let manual = WorkCandidate(provider: "manual", reference: UUID().uuidString, title: "book", author: "author")
        XCTAssertThrowsError(try s.add(work: manual))
        XCTAssertEqual(try s.add(work: manual, choice: .reuse(id)), id)
        let duplicate = try s.add(work: manual, choice: .addAnyway)
        XCTAssertNotEqual(id, duplicate); XCTAssertEqual(try s.bookCount(), 2)
    }
    func testProgressRetryConflictPreservationAndExplicitResolution() throws {
        let s = try store(), id = try s.add(work: work)
        let rid = try s.start(bookID: id, editionID: nil, date: nil), observationID = UUID()
        _ = try s.update(readingID: rid, value: .pages(current: 100), revision: 0, observationID: observationID)
        _ = try s.update(readingID: rid, value: .pages(current: 100), revision: 0, observationID: observationID)
        XCTAssertEqual(try s.record(id: id).active?.progressObservations.count, 1)
        let conflict = UUID()
        _ = try s.update(readingID: rid, value: .pages(current: 50), revision: 0, observationID: conflict)
        XCTAssertEqual(try s.record(id: id).active?.progress.currentPage, 100)
        XCTAssertThrowsError(try s.finish(readingID: rid, confirmed: true, date: nil, revision: 1))
        try s.resolveProgress(readingID: rid, observationID: conflict, apply: true, revision: 1)
        let reading = try XCTUnwrap(s.record(id: id).active)
        XCTAssertEqual(reading.progress.currentPage, 50)
        XCTAssertEqual(reading.progressObservations.count, 3)
        XCTAssertEqual(reading.progressObservations[1].value.currentPage, 50)
    }
    func testDurableReopenAndProvenanceAndNoFakeToReadInstance() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: path) }
        let owner = UUID(), s = try LocalStore(path: path.path, ownerID: owner)
        let id = try s.add(work: work, edition: edition)
        let reopened = try LocalStore(path: path.path, ownerID: owner)
        XCTAssertEqual(try reopened.record(id: id).editions.count, 1)
        XCTAssertTrue(try reopened.record(id: id).readings.isEmpty)
        let pending = try await reopened.pending(ownerID: owner); XCTAssertEqual(pending.count, 2)
        let db = try DatabaseQueue(path: path.path)
        try await db.read { db in
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT source FROM field_provenance WHERE field='title'"), "fixture")
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM journal_components"), 0)
            try db.checkForeignKeys()
        }
        let other = try LocalStore(path: path.path, ownerID: UUID())
        XCTAssertTrue(try other.library().isEmpty); XCTAssertThrowsError(try other.record(id: id))
    }
    func testPageBoundsUnknownTotalAndRealIncrement() throws {
        let s = try store(), id = try s.add(work: work)
        let rid = try s.start(bookID: id, editionID: nil, date: nil)
        _ = try s.update(readingID: rid, value: .pages(current: 183), revision: 0)
        let reading = try XCTUnwrap(s.record(id: id).active)
        XCTAssertEqual(try BooksRules.pageIncrement(74, reading: reading).currentPage, 257)
        XCTAssertThrowsError(try ReadingProgress.pages(current: -1)); XCTAssertThrowsError(try ReadingProgress.pages(current: 2, total: 1)); XCTAssertThrowsError(try ReadingProgress.pages(total: 0))
        XCTAssertThrowsError(try BooksRules.pageIncrement(Int.max, reading: reading))
    }
}
