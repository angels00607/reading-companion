import Foundation
import XCTest
@testable import ReadingDomain

final class InitialTransferApprovalTests: XCTestCase {
    private func plan(title: String) throws -> (UUID, CoreSyncUploadPreview.Plan) {
        let id = UUID()
        let book = try CoreSyncPayloads.Book(title: title, author: "Author",
                                             localRevision: 0, deletedAt: nil)
        return (id, try CoreSyncUploadPreview.make(
            books: [id: book], readings: [:], remoteRecordIDs: []))
    }

    func testApprovalMatchesExactOwnerAccountAndPayload() throws {
        let owner = UUID(), account = UUID()
        let (_, preview) = try plan(title: "Original")
        let approval = try InitialTransferApproval(
            localOwnerID: owner, cloudAccountID: account, approvedAt: Date(),
            records: preview.items)
        XCTAssertTrue(approval.matches(localOwnerID: owner, cloudAccountID: account,
                                       records: preview.items))
        XCTAssertFalse(approval.matches(localOwnerID: UUID(), cloudAccountID: account,
                                        records: preview.items))
        XCTAssertFalse(approval.matches(localOwnerID: owner, cloudAccountID: UUID(),
                                        records: preview.items))
    }

    func testModifiedPayloadInvalidatesApproval() throws {
        let owner = UUID(), account = UUID(), id = UUID()
        let first = try CoreSyncPayloads.Book(title: "Before", author: "Author",
                                              localRevision: 0, deletedAt: nil)
        let second = try CoreSyncPayloads.Book(title: "After", author: "Author",
                                               localRevision: 1, deletedAt: nil)
        let original = try CoreSyncUploadPreview.make(
            books: [id: first], readings: [:], remoteRecordIDs: [])
        let modified = try CoreSyncUploadPreview.make(
            books: [id: second], readings: [:], remoteRecordIDs: [])
        let approval = try InitialTransferApproval(
            localOwnerID: owner, cloudAccountID: account, approvedAt: Date(),
            records: original.items)
        XCTAssertFalse(approval.matches(localOwnerID: owner, cloudAccountID: account,
                                        records: modified.items))
    }

    func testEmptyApprovalIsRejected() throws {
        XCTAssertThrowsError(try InitialTransferApproval(
            localOwnerID: UUID(), cloudAccountID: UUID(),
            approvedAt: Date(), records: []))
    }
}
