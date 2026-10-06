import XCTest
import ReadingDomain
import GRDB
@testable import ReadingData

final class Phase5ChallengesRepositoryTests: XCTestCase {
    private func store() throws -> LocalStore { try LocalStore(path: ":memory:", ownerID: UUID()) }
    private func complete(_ store: LocalStore, title: String = "The Amber Garden", day: Int = 1, month: Int = 3, year: Int = 2027) throws -> UUID {
        let book = try store.add(work: WorkCandidate(provider: "fixture", reference: UUID().uuidString, title: title, author: "Author"))
        let id = try store.start(bookID: book, editionID: nil, date: nil)
        try store.finish(readingID: id, confirmed: true, date: ReadingDate(year: year, month: month, day: day), revision: 0)
        return id
    }
    private func prompt(_ store: LocalStore, _ kind: ChallengeKind, _ key: String, year: Int = 2027) throws -> ChallengePrompt {
        try XCTUnwrap(store.challengeYear(year: year).configuration.prompts.first { $0.challenge == kind && $0.key == key })
    }
    private func proposal(_ reading: UUID, _ prompt: ChallengePrompt, _ score: Int, fingerprint: String = "evidence-v1", reliable: Bool = true) -> ChallengeProposal {
        .init(readingID: reading, promptID: prompt.id, confidence: score, evidence: .init(fingerprint: fingerprint, source: "Verified fixture", reference: "Supplied source", explanation: "Explicit test evidence", reliable: reliable))
    }
    func testConfirmExplicitIdempotentOccupiedAndIndependent() throws {
        let s = try store(), reading = try complete(s)
        let a = try prompt(s,.tropes,"prompt.1"), b = try prompt(s,.archetype,"prompt.1")
        let first = proposal(reading,a,88), second = proposal(reading,b,74)
        try s.storeChallengeProposals([first,second], year: 2027)
        XCTAssertNil(try s.challengeYear(year: 2027).assignment(a))
        XCTAssertEqual(try s.challengeYear(year: 2027).proposals.first?.percentage,"88% MATCH")
        try s.confirmChallengeProposal(id: first.id, year: 2027)
        try s.confirmChallengeProposal(id: first.id, year: 2027)
        XCTAssertEqual(try s.challengeYear(year: 2027).assignments.filter { $0.promptID == a.id }.count,1)
        XCTAssertNil(try s.challengeYear(year: 2027).assignment(b))
        XCTAssertEqual(try s.challengeYear(year: 2027).proposals.first?.id,second.id)
        let other = try complete(s, title: "Another Book", day: 2)
        try s.storeChallengeProposals([proposal(other,a,99)], year: 2027)
        XCTAssertEqual(try s.challengeYear(year: 2027).assignment(a)?.readingID,reading)
        try s.confirmChallengeProposal(id: second.id, year: 2027)
        XCTAssertEqual(try s.challengeYear(year: 2027).assignment(b)?.readingID,reading)
    }
    func testRejectWithoutReasonNextBestSuppressionAndNewEvidence() throws {
        let s = try store(), reading = try complete(s)
        let prompts = try (1...4).map { try prompt(s,.tropes,"prompt.\($0)") }
        let values = zip(prompts,[91,84,70,69]).map { proposal(reading,$0.0,$0.1) }
        try s.storeChallengeProposals(values,year:2027)
        for (id,next) in [(values[0].id,84),(values[1].id,70)] {
            try s.rejectChallengeProposal(id:id,year:2027)
            XCTAssertEqual(try s.challengeYear(year:2027).proposals.first?.confidence,next)
        }
        try s.rejectChallengeProposal(id:values[2].id,year:2027)
        XCTAssertTrue(try s.challengeYear(year:2027).proposals.isEmpty)
        try s.storeChallengeProposals([proposal(reading,prompts[0],99)],year:2027)
        XCTAssertTrue(try s.challengeYear(year:2027).proposals.isEmpty)
        let revised = proposal(reading,prompts[0],82,fingerprint:"materially-changed-v2")
        try s.storeChallengeProposals([revised],year:2027)
        XCTAssertEqual(try s.challengeYear(year:2027).proposals.first?.id,revised.id)
    }
    func testManualHasNoInventedConfidenceAndCannotDisplace() throws {
        let s = try store(), reading = try complete(s)
        let p = try prompt(s,.tropes,"prompt.1")
        try s.assignChallenge(promptID:p.id,readingID:reading,year:2027)
        let assignment = try XCTUnwrap(s.challengeYear(year:2027).assignment(p))
        XCTAssertNil(assignment.confidence); XCTAssertNil(assignment.evidence); XCTAssertEqual(assignment.source,"manual")
        let later = try complete(s,title:"Later",day:2)
        XCTAssertThrowsError(try s.assignChallenge(promptID:p.id,readingID:later,year:2027))
        XCTAssertEqual(try s.challengeYear(year:2027).assignment(p)?.id,assignment.id)
    }
    func testSeasonalMonthlyAndTBDValidationIsTransactional() throws {
        let s = try store(), reading = try complete(s)
        let wrongSeason = try prompt(s,.seasonal,"winter.1"), wrongMonth = try prompt(s,.monthly,"4.1")
        for p in [wrongSeason,wrongMonth,try prompt(s,.archetype,"prompt.10"),try prompt(s,.monthly,"12.2"),try prompt(s,.roulette,"1")] {
            XCTAssertThrowsError(try s.assignChallenge(promptID:p.id,readingID:reading,year:2027))
            XCTAssertNil(try s.challengeYear(year:2027).assignment(p))
        }
    }
    func testWeekEarliestAndReplacementOnlySameISOWeek() throws {
        let s = try store(), late = try complete(s,title:"Later Book",day:3), first = try complete(s,title:"Earlier Book",day:1)
        let p = try prompt(s,.weeks,"9")
        XCTAssertEqual(try s.challengeYear(year:2027).assignment(p)?.readingID,first)
        let different = try complete(s,day:10)
        XCTAssertThrowsError(try s.replaceChallengeWeek(promptID:p.id,readingID:different,year:2027,confirmed:true))
        XCTAssertThrowsError(try s.replaceChallengeWeek(promptID:p.id,readingID:late,year:2027,confirmed:false))
        try s.replaceChallengeWeek(promptID:p.id,readingID:late,year:2027,confirmed:true)
        try s.ensureChallengeYear(year:2027)
        XCTAssertEqual(try s.challengeYear(year:2027).assignment(p)?.readingID,late)
        XCTAssertEqual(try s.challengeYear(year:2027).assignment(p)?.source,"manual")
    }
    func testSameDayTieStaysUnfilledUntilManualChoice() throws {
        let s = try store(), first = try complete(s,day:1)
        _ = try complete(s,title:"Same Day",day:1)
        let p = try prompt(s,.weeks,"9")
        XCTAssertNil(try s.challengeYear(year:2027).assignment(p))
        try s.assignChallenge(promptID:p.id,readingID:first,year:2027)
        try s.ensureChallengeYear(year:2027)
        XCTAssertEqual(try s.challengeYear(year:2027).assignment(p)?.readingID,first)
    }
    func testWeek53UnconfiguredAndFinishYearNotStartYear() throws {
        let s = try store(); _ = try complete(s,day:3,month:1,year:2027)
        XCTAssertTrue(try s.challengeYear(year:2026).assignments.isEmpty)
        XCTAssertFalse(try s.challengeYear(year:2026).configuration.prompts.contains { $0.challenge == .weeks && $0.key == "53" })
        let monday = try complete(s,title:"Monday Book",day:4,month:1)
        XCTAssertEqual(try s.challengeYear(year:2027).assignment(prompt(s,.weeks,"1"))?.readingID,monday)
    }
    func testUnknownFinishDNFAndHistoricalDoNotCreateAutomaticWork() async throws {
        let s = try store()
        let book = try s.add(work: WorkCandidate(provider:"fixture",reference:"none",title:"Book",author:"Author"))
        let reading = try s.start(bookID:book,editionID:nil,date:nil)
        try s.markDNF(readingID:reading,revision:0)
        XCTAssertTrue(try s.challengeYears().isEmpty)
        let pending = try await s.pending(ownerID:s.ownerID)
        XCTAssertFalse(pending.contains { $0.kind.hasPrefix("challenge.") })
        let imported = try s.recordCompleted(bookID:book,editionID:nil,date:ReadingDate(year:2027,month:3,day:1),rating:.noRating)
        try s.ensureChallengeYear(year:2027)
        XCTAssertTrue(try s.challengeYear(year:2027).assignments.isEmpty)
        let p = try prompt(s,.tropes,"prompt.1")
        XCTAssertThrowsError(try s.storeChallengeProposals([proposal(imported,p,90)],year:2027))
        try s.assignChallenge(promptID:p.id,readingID:imported,year:2027)
        XCTAssertEqual(try s.challengeYear(year:2027).assignment(p)?.readingID,imported)
    }
    func testAlphabetSeriesMaximumTwoBooks() throws {
        let s = try store()
        let ids = try ["The Amber Garden","The Blue Notebook","The Crimson Moon"].map { try complete(s,title:$0) }
        let books = try s.challengeYear(year:2027).readings.filter { ids.contains($0.id) }
        let series = ReadingSeries(ownerID:s.ownerID,name:"Same Series")
        try s.saveSeries(series,entries:books.enumerated().map { index,value in SeriesEntry(seriesID:series.id,bookID:value.book.id,title:value.book.title,position:Decimal(index+1),kind:.main,publication:.published,release:.unknown) })
        try s.assignChallenge(promptID:prompt(s,.alphabet,"1").id,readingID:ids[0],year:2027)
        try s.assignChallenge(promptID:prompt(s,.alphabet,"2").id,readingID:ids[1],year:2027)
        XCTAssertThrowsError(try s.assignChallenge(promptID:prompt(s,.alphabet,"3").id,readingID:ids[2],year:2027))
    }
    func testHundredCompletionSlotsNeverConfidence() throws {
        let s = try store(); _ = try complete(s); _ = try complete(s,title:"Second",day:2)
        let state = try s.challengeYear(year:2027)
        let slots = Set(state.configuration.prompts.filter { $0.challenge == .hundred }.map(\.id))
        let values = state.assignments.filter { slots.contains($0.promptID) }
        XCTAssertEqual(values.count,2); XCTAssertTrue(values.allSatisfy { $0.confidence == nil && $0.evidence == nil })
        XCTAssertTrue(state.proposals.isEmpty)
    }
    func testSnapshotArchiveOfflineReopenAndImmutability() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite").path
        defer { try? FileManager.default.removeItem(atPath:path) }
        let owner = UUID(), s = try LocalStore(path:path,ownerID:owner)
        try s.ensureChallengeYear(year:2026); let saved = try s.challengeYear(year:2026).configuration
        try s.ensureChallengeYear(year:2027); try s.ensureChallengeYear(year:2028)
        XCTAssertThrowsError(try s.queue.write { try $0.execute(sql:"UPDATE challenge_years SET content_json='{}' WHERE owner_id=? AND year=2026",arguments:[owner.uuidString]) })
        XCTAssertThrowsError(try s.queue.write { try $0.execute(sql:"DELETE FROM challenge_prompts WHERE owner_id=?",arguments:[owner.uuidString]) })
        let reopened = try LocalStore(path:path,ownerID:owner)
        XCTAssertEqual(try reopened.challengeYear(year:2026).configuration,saved)
        XCTAssertEqual(try reopened.challengeYears(),[2028,2027,2026])
        let another = try LocalStore(path:path,ownerID:UUID())
        XCTAssertTrue(try another.challengeYears().isEmpty)
    }
    func testChallengeReadyAndAttentionDoNotBlockBookReviewAndCopiedChangesUseCorrection() throws {
        let s = try store(), reading = try complete(s)
        XCTAssertEqual(try s.journalEntry(readingID:reading).components[.challenges],.ready)
        XCTAssertEqual(try s.journalEntry(readingID:reading).bookReviewState,.pending)
        let p = try prompt(s,.tropes,"prompt.1"), candidate = proposal(reading,p,70)
        try s.storeChallengeProposals([candidate],year:2027)
        XCTAssertEqual(try s.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM attention_items WHERE category='challenges' AND status='open'") },1)
        try s.markChallengesCopied(readingID:reading)
        try s.confirmChallengeProposal(id:candidate.id,year:2027)
        XCTAssertTrue(try s.corrections().contains { $0.component == .challenges && !$0.resolved })
        XCTAssertEqual(try s.journalEntry(readingID:reading).bookReviewState,.pending)
    }
    func testInvalidProposalBatchRollsBackWithoutOccupyingAnything() throws {
        let s = try store(), reading = try complete(s)
        let p = try prompt(s,.tropes,"prompt.1")
        XCTAssertThrowsError(try s.storeChallengeProposals([proposal(reading,p,80),proposal(reading,p,99,reliable:false)],year:2027))
        XCTAssertTrue(try s.challengeYear(year:2027).proposals.isEmpty)
        XCTAssertNil(try s.challengeYear(year:2027).assignment(p))
    }
    func testExplicitClearPreservedAgainstAutomaticRepopulation() throws {
        let s = try store(), reading = try complete(s)
        let p = try prompt(s,.hundred,"1")
        let assignment = try XCTUnwrap(s.challengeYear(year:2027).assignment(p))
        try s.removeChallengeAssignment(id:assignment.id,year:2027,confirmed:true)
        try s.ensureChallengeYear(year:2027)
        XCTAssertNil(try s.challengeYear(year:2027).assignment(p))
        try s.assignChallenge(promptID:p.id,readingID:reading,year:2027)
        XCTAssertEqual(try s.challengeYear(year:2027).assignment(p)?.source,"manual")
    }
    func testReadingDateCorrectionPreservesAssignmentAndCreatesAttention() throws {
        let s = try store(), reading = try complete(s)
        let p = try prompt(s,.monthly,"3.1")
        try s.assignChallenge(promptID:p.id,readingID:reading,year:2027)
        let state = try s.challengeYear(year:2027)
        let record = try XCTUnwrap(state.readings.first { $0.id == reading })
        try s.editReading(readingID:reading,start:nil,finish:ReadingDate(year:2027,month:4,day:1),rating:.unknown,genre:nil,format:nil,revision:record.reading.revision)
        XCTAssertEqual(try s.challengeYear(year:2027).assignment(p)?.readingID,reading)
        XCTAssertTrue(try s.challengeYear(year:2027).assignmentsNeedingReview.contains { $0.promptID == p.id })
        XCTAssertGreaterThan(try s.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM attention_items WHERE reason='eligibility-changed' AND status='open'")! },0)
    }
    func testNewMaterialEvidenceRetiresUnconfirmedOldEvidenceOnly() throws {
        let s = try store(), reading = try complete(s)
        let p = try prompt(s,.tropes,"prompt.1")
        try s.storeChallengeProposals([proposal(reading,p,99)],year:2027)
        let newer = proposal(reading,p,74,fingerprint:"new-reliable-evidence")
        try s.storeChallengeProposals([newer],year:2027)
        XCTAssertEqual(try s.challengeYear(year:2027).proposals.first?.id,newer.id)
    }

    func testUnknownFinishAllowsExplicitUnscopedManualButNotInventedPeriod() throws {
        let s = try store();try s.ensureChallengeYear(year:2027)
        let book = try s.add(work:WorkCandidate(provider:"fixture",reference:"unknown-date",title:"Unknown Date",author:"Author"))
        let reading = try s.start(bookID:book,editionID:nil,date:nil)
        try s.finish(readingID:reading,confirmed:true,date:nil,revision:0)
        let p = try prompt(s,.tropes,"prompt.1")
        try s.assignChallenge(promptID:p.id,readingID:reading,year:2027)
        XCTAssertNotNil(try s.challengeYear(year:2027).assignment(p))
        XCTAssertThrowsError(try s.assignChallenge(promptID:prompt(s,.weeks,"1").id,readingID:reading,year:2027))
        XCTAssertThrowsError(try s.assignChallenge(promptID:prompt(s,.monthly,"1.1").id,readingID:reading,year:2027))
        XCTAssertNil(try s.record(id:book).latest?.finishDate)
    }

}
