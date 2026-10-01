import XCTest
@testable import ReadingDomain

final class InvariantTests: XCTestCase {
    func testFinalPageDoesNotCompleteAndUnknownPagesCanFinish() throws {
        var reading = try ReadingInstance(bookID: UUID(), progress: .pages(current: 0, total: 100))
        let update = try ProgressRules.record(&reading, value: .pages(current: 100, total: 100), expectedRevision: 0)
        guard case .applied(let observation) = update else { return XCTFail("Expected applied observation") }
        XCTAssertEqual(observation.genuinePageDelta, 100)
        XCTAssertEqual(reading.status, .currentlyReading)
        XCTAssertThrowsError(try ReadingRules.finish(&reading, confirmed: false, date: nil, expectedRevision: 1))
        var unknown = try ReadingInstance(bookID: UUID(), progress: .pages())
        let effects = try ReadingRules.finish(&unknown, confirmed: true, date: nil, expectedRevision: 0)
        XCTAssertTrue(effects.journalInbox)
    }
    func testDNFPreservesProgressAndCannotFinishUntilResumed() throws {
        var reading = try ReadingInstance(bookID: UUID(), progress: .pages(current: 74))
        try ReadingRules.markDNF(&reading)
        XCTAssertEqual(reading.progress.currentPage, 74)
        XCTAssertFalse(ReadingRules.includedInCompletedStats(reading))
        XCTAssertThrowsError(try ReadingRules.finish(&reading, confirmed: true, date: nil, expectedRevision: 1))
        try ReadingRules.resume(&reading)
        XCTAssertEqual(reading.progress.currentPage, 74)
    }
    func testHistoricalReadingDoesNotReplayLiveEffects() throws {
        var reading = try ReadingInstance(bookID: UUID(), progress: .pages(), historical: true)
        let effects = try ReadingRules.finish(&reading, confirmed: true, date: nil, expectedRevision: 0)
        XCTAssertFalse(effects.journalInbox); XCTAssertFalse(effects.challengeAnalysis); XCTAssertFalse(effects.rewardEligible)
        XCTAssertTrue(ReadingRules.includedInCompletedStats(reading))
    }
    func testRereadIdentityAndExternalFormatBoundary() throws {
        let book = UUID()
        var first = try ReadingInstance(bookID: book, progress: .pages())
        let second = try ReadingInstance(bookID: book, progress: .pages())
        XCTAssertNotEqual(first.id, second.id); XCTAssertEqual(first.bookID, second.bookID)
        for origin in [MutationOrigin.provider, .historicalImport, .restore] {
            XCTAssertThrowsError(try ReadingRules.setJournalFormat(.ebook, origin: origin, reading: &first))
        }
        XCTAssertNil(first.journalFormat)
        try ReadingRules.setJournalFormat(.ebook, origin: .user, reading: &first)
        XCTAssertEqual(first.journalFormat, .ebook)
    }
    func testOverridesRejectionsAndNoHighestPageWins() throws {
        XCTAssertEqual(OverridePolicy.decide(current: 100, incoming: 120, userOverridden: true, origin: .provider), .review)
        XCTAssertFalse(OverridePolicy.mayPropose(fingerprint: "v1", rejected: ["v1"]))
        XCTAssertTrue(OverridePolicy.mayPropose(fingerprint: "v2", rejected: ["v1"]))
        var reading = try ReadingInstance(bookID: UUID(), progress: .pages(current: 100))
        let update = try ProgressRules.record(&reading, value: .pages(current: 80), expectedRevision: 0)
        guard case .applied(let observation) = update else { return XCTFail("Expected applied correction") }
        XCTAssertEqual(observation.genuinePageDelta, -20)
        let conflict = try ProgressRules.record(&reading, value: .pages(current: 120), expectedRevision: 0)
        guard case .requiresReview = conflict else { return XCTFail("Stale progress must be retained for review") }
        XCTAssertEqual(reading.progress.currentPage, 80)
    }
    func testChallengeVersionsConfidenceTBDAndISOWeek() throws {
        XCTAssertEqual(ChallengeRules.version(year: 2027), .b)
        XCTAssertFalse(ChallengeRules.semanticProposalAllowed(confidence: 69, reliable: true, occupied: false))
        XCTAssertFalse(ChallengeRules.semanticProposalAllowed(confidence: 90, reliable: false, occupied: false))
        XCTAssertFalse(ChallengeRules.semanticProposalAllowed(confidence: 90, reliable: true, occupied: true))
        XCTAssertFalse(ChallengeRules.promptEligible(isTBD: true))
        XCTAssertTrue(ChallengeRules.sameWeek(try ReadingDate(year: 2020, month: 12, day: 31),
                                            try ReadingDate(year: 2021, month: 1, day: 3)))
        XCTAssertThrowsError(try ReadingDate(year: 2027, month: 2, day: 29))
    }
    func testJournalAndSeriesRules() throws {
        XCTAssertEqual(JournalRules.bookReviewCapacity, 100)
        XCTAssertFalse(JournalRules.bookReviewReady(requiredFieldsPresent: true, format: nil))
        XCTAssertTrue(JournalRules.correctionRequired(copied: "old", current: "new"))
        XCTAssertEqual(SeriesRules.trackerPages(entryCount: 41), 3)
        XCTAssertEqual(SeriesRules.effectiveStatus(override: .abandoned, evidence: .init(hasUnreadIncludedPublished: true)), .abandoned)
        XCTAssertEqual(SeriesRules.effectiveStatus(override: nil, evidence: .init(allIncludedPublishedRead: true, knownOngoing: true)), .waiting)
    }
    func testRestoreCannotLoseOrDuplicateXP() throws {
        let a = try XPAward(semanticKey: "completion:a", amount: 10)
        let b = try XPAward(semanticKey: "completion:b", amount: 20)
        let result = try XPPolicy.merge(existing: [a,b], restored: [a])
        XCTAssertEqual(result.reduce(0) { $0 + $1.amount }, 30)
        XCTAssertThrowsError(try XPAward(semanticKey: "bad", amount: -1))
        XCTAssertThrowsError(try XPPolicy.merge(existing: [a], restored: [XPAward(semanticKey: a.semanticKey, amount: 5)]))
        XCTAssertThrowsError(try Rating.validatedStars(0))
        XCTAssertNotEqual(Rating.unknown, .noRating)
    }
}
