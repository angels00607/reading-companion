import Foundation
import XCTest
@testable import ReadingDomain

final class InitialTransferRecoveryIdentityTests: XCTestCase {
    func testDifferentCloudOwnerBlocksResume() {
        let expected = UUID()
        let result = InitialTransferRecovery.reconcileVerified(
            cloudAccountID: expected,
            approvedPayloads: ["book:a": Data("same".utf8)],
            successfulRevisions: ["book:a": 1],
            remoteRecords: ["book:a": .init(ownerID: UUID(), revision: 1,
                                              payload: Data("same".utf8), isDeleted: false)])
        XCTAssertFalse(result.canResume)
        XCTAssertEqual(result.conflictingIDs, ["book:a"])
    }

    func testTombstoneBlocksResumeEvenWithMatchingPayload() {
        let expected = UUID()
        let result = InitialTransferRecovery.reconcileVerified(
            cloudAccountID: expected,
            approvedPayloads: ["book:a": Data("same".utf8)],
            successfulRevisions: ["book:a": 1],
            remoteRecords: ["book:a": .init(ownerID: expected, revision: 1,
                                              payload: Data("same".utf8), isDeleted: true)])
        XCTAssertFalse(result.canResume)
    }
}
