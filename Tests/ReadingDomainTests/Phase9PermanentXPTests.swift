import XCTest
@testable import ReadingDomain

final class Phase9PermanentXPTests: XCTestCase {
    private func award(_ key: String, amount: Int = 100, date: Date = Date(timeIntervalSince1970: 1000)) throws -> XPAward {
        try .init(semanticKey: key, source: .finishBook, amount: amount, awardedAt: date)
    }
    func testCurrentABAndBackupACMergeABCExactlyOnce() throws {
        let a = try award("finish-book:a"), b = try award("finish-book:b"), c = try award("finish-book:c")
        let first = try XPPolicy.merge(existing: [a, b], restored: [a, c, c])
        let retry = try XPPolicy.merge(existing: first, restored: [a, c])
        XCTAssertEqual(first, retry)
        XCTAssertEqual(first.map(\.semanticKey), ["finish-book:a", "finish-book:b", "finish-book:c"])
        XCTAssertEqual(first.reduce(0) { $0 + $1.amount }, 300)
    }
    func testDuplicateBackupDoesNotRewritePermanentIdentityOrTimestamp() throws {
        let existing = try award("finish-book:a"), restored = try award("finish-book:a", date: Date(timeIntervalSince1970: 9999))
        XCTAssertEqual(try XPPolicy.merge(existing: [existing], restored: [restored]), [existing])
    }
    func testSameKeyDifferentSourceIsUnresolvedConflict() throws {
        let existing = try award("finish-book:a")
        let conflicting = try XPAward(semanticKey: existing.semanticKey, source: .weeklyQuest, amount: 100)
        XCTAssertThrowsError(try XPPolicy.merge(existing: [existing], restored: [conflicting]))
        XCTAssertEqual(existing.amount, 100)
    }
    func testDecodedInvalidAwardCannotBypassMergeValidation() throws {
        let existing = try award("finish-book:a")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(existing)) as? [String: Any])
        for change in [["amount": -1], ["semanticKey": " "]] as [[String: Any]] {
            let data = try JSONSerialization.data(withJSONObject: object.merging(change) { _, new in new })
            let invalid = try JSONDecoder().decode(XPAward.self, from: data)
            XCTAssertThrowsError(try XPPolicy.merge(existing: [existing], restored: [invalid]))
        }
        object["semanticKey"] = "finish-book:overflow"; object["amount"] = Int.max
        let overflow = try JSONDecoder().decode(XPAward.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try XPPolicy.merge(existing: [existing], restored: [overflow]))
    }
    func testOlderBackupNeverReducesLegitimateCurrentXP() throws {
        let a = try award("finish-book:a"), b = try award("finish-book:b")
        XCTAssertEqual(try XPPolicy.merge(existing: [a, b], restored: []), [a, b])
    }
}
