import XCTest
@testable import ReadingDomain

final class CloudSyncContractTests: XCTestCase {
    private let owner = UUID()
    private let record = UUID()

    private func make(_ value: Int, deleted: Bool = false) throws -> CloudReadingRecord {
        try CloudReadingRecord(ownerID: owner, recordType: .book,
                               recordID: record, payload: Data("{\"value\":\(value)}".utf8),
                               revision: Int64(value), isDeleted: deleted)
    }

    func testBothEditedRequiresReview() throws {
        let base = try make(1)
        XCTAssertEqual(ReadingSyncPlanner.decide(local: try make(2), remote: try make(3), base: base), .needsUserReview)
    }

    func testOneSidedEdit() throws {
        let base = try make(1)
        XCTAssertEqual(ReadingSyncPlanner.decide(local: try make(2), remote: base, base: base), .uploadLocal)
        XCTAssertEqual(ReadingSyncPlanner.decide(local: base, remote: try make(2), base: base), .downloadRemote)
    }

    func testUnknownBaseWithTwoCopiesRequiresReview() throws {
        XCTAssertEqual(ReadingSyncPlanner.decide(local: try make(1), remote: try make(2), base: nil), .needsUserReview)
    }

    func testDeletionVsModificationRequiresReview() throws {
        let base = try make(1)
        XCTAssertEqual(ReadingSyncPlanner.decide(local: try make(2, deleted: true), remote: try make(3), base: base), .needsUserReview)
    }

    func testInvalidPayloadAndRevisionRejected() {
        XCTAssertThrowsError(try CloudReadingRecord(ownerID: owner, recordType: .book, recordID: record,
                                                    payload: Data("[]".utf8), revision: 1))
        XCTAssertThrowsError(try CloudReadingRecord(ownerID: owner, recordType: .book, recordID: record,
                                                    payload: Data("{}".utf8), revision: 0))
    }
}
