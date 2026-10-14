import XCTest
@testable import ReadingDomain

final class CoreSyncPayloadsTests: XCTestCase {
    func testBookRoundTripPreservesRevisionAndDeletion() throws {
        let book = try CoreSyncPayloads.Book(title: "Title", author: "Author", localRevision: 12, deletedAt: nil)
        let restored = try JSONDecoder().decode(CoreSyncPayloads.Book.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(book, restored)
        XCTAssertEqual(restored.schemaVersion, 1)
    }

    func testReadingRoundTripPreservesManualFormatAndDates() throws {
        let reading = try CoreSyncPayloads.Reading(
            bookID: UUID(), editionID: nil, status: .read, currentPage: 345,
            totalPages: 345, startDate: "2026-10-01", finishDate: "2026-10-14",
            ratingState: .rated, ratingWhole: 5, journalFormat: .hardcover,
            historical: false, localRevision: 7, deletedAt: nil)
        let restored = try JSONDecoder().decode(CoreSyncPayloads.Reading.self, from: JSONEncoder().encode(reading))
        XCTAssertEqual(reading, restored)
        XCTAssertEqual(restored.journalFormat, .hardcover)
    }

    func testDNFIsPreservedAndNotConvertedToCompleted() throws {
        let reading = try CoreSyncPayloads.Reading(
            bookID: UUID(), editionID: nil, status: .dnf, currentPage: 80,
            totalPages: 300, startDate: nil, finishDate: nil,
            ratingState: .unrated, ratingWhole: nil, journalFormat: .ebook,
            historical: false, localRevision: 1, deletedAt: nil)
        XCTAssertEqual(try JSONDecoder().decode(CoreSyncPayloads.Reading.self,
            from: JSONEncoder().encode(reading)).status, .dnf)
    }

    func testInvalidRatingCannotBeExported() {
        XCTAssertThrowsError(try CoreSyncPayloads.Reading(
            bookID: UUID(), editionID: nil, status: .read, currentPage: 1,
            totalPages: 10, startDate: nil, finishDate: nil,
            ratingState: .rated, ratingWhole: 6, journalFormat: nil,
            historical: false, localRevision: 0, deletedAt: nil))
    }
}
