import XCTest
import ReadingDomain
@testable import ReadingData

final class Phase4SeriesRepositoryTests: XCTestCase {
    func testLocalOfflineSeriesProposalSuppressionAndJournalIndependence() throws {
        let owner = UUID(), store = try LocalStore(path: ":memory:", ownerID: owner), id = UUID()
        let value = ReadingSeries(id: id, ownerID: owner, name: "The Local Series", evidence: .init(hasUnreadIncludedPublished: true))
        let first = SeriesEntry(seriesID: id, bookID: nil, title: "First", position: Decimal(string: "0.5")!, kind: .main, publication: .published, release: .unknown)
        try store.saveSeries(value, entries: [first])
        XCTAssertEqual(try store.series(query: "First", filter: .active, sort: .alphabetical).first?.series.id, id)
        try store.propose(seriesID: id, field: "Series name", current: value.name, proposed: "Proposed Name", source: "Catalogue", evidenceFingerprint: "A/X")
        XCTAssertEqual(try store.seriesDetail(id: id).series.name, value.name)
        let proposal = try XCTUnwrap(store.proposals(seriesID: id).first)
        try store.rejectProposal(id: proposal.id)
        try store.propose(seriesID: id, field: "Series name", current: value.name, proposed: "Proposed Name", source: "Catalogue", evidenceFingerprint: "A/X")
        XCTAssertTrue(try store.proposals(seriesID: id).isEmpty)
        try store.propose(seriesID: id, field: "Series name", current: value.name, proposed: "Changed Evidence", source: "Catalogue", evidenceFingerprint: "A/Y")
        XCTAssertEqual(try store.proposals(seriesID: id).count, 1)
    }
    func testSeriesReadinessDoesNotChangeBookReviewComponent() throws {
        let owner = UUID(), store = try LocalStore(path: ":memory:", ownerID: owner)
        let book = try store.add(work: WorkCandidate(provider: "manual", reference: UUID().uuidString, title: "Series Book", author: "Author"))
        let reading = try store.start(bookID: book, editionID: nil, date: nil)
        try store.finish(readingID: reading, confirmed: true, date: nil, revision: 0)
        let id = UUID(), value = ReadingSeries(id: id, ownerID: owner, name: "Series", evidence: .init(allIncludedPublishedRead: true))
        try store.saveSeries(value, entries: [SeriesEntry(seriesID: id, bookID: book, title: "Series Book", position: 1, kind: .main, publication: .published, release: .unknown, isRead: true)])
        let entry = try store.journalEntry(readingID: reading)
        XCTAssertEqual(entry.components[.series], .ready)
        XCTAssertEqual(entry.components[.bookReview], .pending)
        XCTAssertEqual(entry.components[.challenges], .pending)
    }
}
