import Foundation
import XCTest
@testable import ReadingDomain

final class CoreSyncUploadPreviewTests: XCTestCase {
    func testNewBookAndReadingArePreparedWithoutUpload() throws {
        let bookID = UUID(), readingID = UUID()
        let book = try CoreSyncPayloads.Book(title: "A", author: "B", localRevision: 0, deletedAt: nil)
        let reading = try CoreSyncPayloads.Reading(
            bookID: bookID, editionID: nil, status: .dnf, currentPage: 20,
            totalPages: 200, startDate: nil, finishDate: nil,
            ratingState: .unrated, ratingWhole: nil, journalFormat: .ebook,
            historical: false, localRevision: 0, deletedAt: nil)
        let plan = try CoreSyncUploadPreview.make(
            books: [bookID: book], readings: [readingID: reading], remoteRecordIDs: [])
        XCTAssertTrue(plan.canUpload)
        XCTAssertEqual(plan.items.count, 2)
        XCTAssertEqual(plan.items.map(\.recordType), [.book, .reading])
    }

    func testExistingRemoteRecordRequiresReview() throws {
        let id = UUID()
        let book = try CoreSyncPayloads.Book(title: "A", author: "B", localRevision: 0, deletedAt: nil)
        let plan = try CoreSyncUploadPreview.make(
            books: [id: book], readings: [:], remoteRecordIDs: ["book:\(id.uuidString)"])
        XCTAssertFalse(plan.canUpload)
        XCTAssertTrue(plan.items.isEmpty)
    }

    func testUnconfirmedDeletionRequiresReview() throws {
        let id = UUID()
        let book = try CoreSyncPayloads.Book(title: "A", author: "B", localRevision: 1, deletedAt: "2026-10-14")
        let plan = try CoreSyncUploadPreview.make(books: [id: book], readings: [:], remoteRecordIDs: [])
        XCTAssertFalse(plan.canUpload)
    }
}
