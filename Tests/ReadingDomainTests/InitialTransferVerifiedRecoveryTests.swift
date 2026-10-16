import Foundation
import XCTest
@testable import ReadingDomain

final class InitialTransferVerifiedRecoveryTests: XCTestCase {
    func testMatchingRevisionButAlteredPayloadBlocksResume() {
        let result = InitialTransferRecovery.reconcileVerified(
            approvedPayloads: ["book:a": Data("approved".utf8)],
            successfulRevisions: ["book:a": 1],
            remoteRecords: ["book:a": (revision: 1, payload: Data("changed".utf8))])
        XCTAssertFalse(result.canResume)
        XCTAssertEqual(result.conflictingIDs, ["book:a"])
    }

    func testMatchingRevisionAndExactPayloadAllowsRemainingRecords() {
        let result = InitialTransferRecovery.reconcileVerified(
            approvedPayloads: [
                "book:a": Data("approved".utf8),
                "book:b": Data("waiting".utf8)],
            successfulRevisions: ["book:a": 1],
            remoteRecords: ["book:a": (revision: 1, payload: Data("approved".utf8))])
        XCTAssertTrue(result.canResume)
        XCTAssertEqual(result.completedIDs, ["book:a"])
        XCTAssertEqual(result.remainingIDs, ["book:b"])
    }
}
