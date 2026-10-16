import Foundation
import XCTest
@testable import ReadingDomain

final class InitialTransferRecoveryTests: XCTestCase {
    func testInterruptedTransferKeepsOnlyUnwrittenItemsPending() {
        let result = InitialTransferRecovery.reconcile(
            approvedRecordIDs: ["book:a", "book:b"],
            successfulRevisions: ["book:a": 1],
            remoteRevisions: ["book:a": 1])
        XCTAssertTrue(result.canResume)
        XCTAssertEqual(result.completedIDs, ["book:a"])
        XCTAssertEqual(result.remainingIDs, ["book:b"])
    }

    func testUnexpectedRemoteDataBlocksResumption() {
        let result = InitialTransferRecovery.reconcile(
            approvedRecordIDs: ["book:a"],
            successfulRevisions: [:],
            remoteRevisions: ["book:unrelated": 1])
        XCTAssertFalse(result.canResume)
        XCTAssertEqual(result.conflictingIDs, ["book:unrelated"])
    }

    func testChangedRevisionBlocksResumption() {
        let result = InitialTransferRecovery.reconcile(
            approvedRecordIDs: ["book:a"],
            successfulRevisions: ["book:a": 1],
            remoteRevisions: ["book:a": 2])
        XCTAssertFalse(result.canResume)
    }

    func testRemoteRecordWithoutReceiptCannotBeOverwritten() {
        let result = InitialTransferRecovery.reconcile(
            approvedRecordIDs: ["book:a"],
            successfulRevisions: [:],
            remoteRevisions: ["book:a": 1])
        XCTAssertFalse(result.canResume)
    }
}
