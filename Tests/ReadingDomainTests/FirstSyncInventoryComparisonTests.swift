import Foundation
import XCTest
@testable import ReadingDomain

final class FirstSyncInventoryComparisonTests: XCTestCase {
    func testLocalOnlyBookIsNew() throws {
        let id = UUID()
        let book = try CoreSyncPayloads.Book(title: "Book", author: "Author",
                                             localRevision: 0, deletedAt: nil)
        let plan = try CoreSyncUploadPreview.make(books: [id: book],
                                                  readings: [:], remoteRecordIDs: [])
        let result = FirstSyncInventoryComparison.compare(local: plan, remote: [])
        XCTAssertEqual(result.newLocalIDs, ["book:\(id.uuidString)"])
        XCTAssertFalse(result.requiresReview)
    }

    func testOverlappingIDsRequireReview() throws {
        let id = UUID(), owner = UUID()
        let book = try CoreSyncPayloads.Book(title: "Book", author: "Author",
                                             localRevision: 0, deletedAt: nil)
        let plan = try CoreSyncUploadPreview.make(books: [id: book],
                                                  readings: [:], remoteRecordIDs: [])
        let remote = try CloudReadingRecord(ownerID: owner, recordType: .book,
                                            recordID: id, payload: Data("{}".utf8),
                                            revision: 1)
        let result = FirstSyncInventoryComparison.compare(local: plan, remote: [remote])
        XCTAssertTrue(result.requiresReview)
        XCTAssertEqual(result.overlappingIDs, ["book:\(id.uuidString)"])
    }

    func testRemoteOnlyRecordRequiresReview() throws {
        let remote = try CloudReadingRecord(ownerID: UUID(), recordType: .book,
                                            recordID: UUID(), payload: Data("{}".utf8),
                                            revision: 1)
        let plan = try CoreSyncUploadPreview.make(books: [:], readings: [:], remoteRecordIDs: [])
        let result = FirstSyncInventoryComparison.compare(local: plan, remote: [remote])
        XCTAssertTrue(result.requiresReview)
        XCTAssertEqual(result.remoteOnlyIDs, [remote.id])
    }
}
