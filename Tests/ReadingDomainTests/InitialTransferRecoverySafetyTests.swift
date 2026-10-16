import Foundation
import XCTest
@testable import ReadingDomain

final class InitialTransferRecoverySafetyTests: XCTestCase {
    func testReceiptWithoutRemoteRowBlocksRecovery() {
        let result = InitialTransferRecovery.reconcile(
            approvedRecordIDs: ["book:a"],
            successfulRevisions: ["book:a": 1],
            remoteRevisions: [:])
        XCTAssertFalse(result.canResume)
        XCTAssertEqual(result.conflictingIDs, ["book:a"])
    }

    func testUnapprovedReceiptBlocksRecovery() {
        let result = InitialTransferRecovery.reconcile(
            approvedRecordIDs: ["book:a"],
            successfulRevisions: ["book:unapproved": 1],
            remoteRevisions: [:])
        XCTAssertFalse(result.canResume)
        XCTAssertEqual(result.conflictingIDs, ["book:unapproved"])
    }
}
