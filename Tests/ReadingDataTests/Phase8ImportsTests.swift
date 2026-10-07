import XCTest
import GRDB
import ReadingDomain
@testable import ReadingData

final class Phase8ImportsTests:XCTestCase {
    private func store() throws -> LocalStore { try LocalStore(path:":memory:",ownerID:UUID()) }
    private let header="Title,Authors,ISBN/UID,Read Status,Read Count,Dates Read,Last Date Read,Star Rating,Format\n"
    private func csv(_ row:String="Archive,Author,uid1,read,1,,2024/02/03,4,ebook\n") -> Data { Data((header+row).utf8) }
    @discardableResult private func apply(_ s:LocalStore,_ data:Data) throws -> ImportHistory { try s.applyImport(s.previewStoryGraph(data),confirmed:true) }
    private func count(_ s:LocalStore,_ table:String) throws -> Int { try s.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM \(table)") ?? 0 } }
    func testBulkHistoryAwardsZeroXP() throws {
        let s=try store();let data=csv((0..<500).map { "Book \($0),Author,uid\($0),read,1,,2024/02/03,4,ebook\n" }.joined())
        let run=try apply(s,data);XCTAssertEqual(run.newBooks,500);XCTAssertEqual(run.newReadings,500);XCTAssertTrue(try s.xpAwards().isEmpty)
    }
    func testImportDoesNotAdvanceQuestsOnApplyOrRefresh() throws {
        let s=try store();let before=try s.currentQuests();try apply(s,csv());let after=try s.currentQuests()
        XCTAssertEqual(before.map(\.progress),after.map(\.progress));XCTAssertEqual(try count(s,"gamification_activity"),0)
    }
    func testImportCannotUnlockAchievementsAfterEvaluation() throws {
        let s=try store();try apply(s,csv((0..<12).map { "Book \($0),Author,uid\($0),read,1,,2024/02/03,4,ebook\n" }.joined()));_ = try s.currentQuests()
        XCTAssertTrue(try s.achievementProgress().allSatisfy { !$0.isUnlocked });XCTAssertTrue(try s.xpAwards().isEmpty)
    }
    func testHistoryDoesNotCascadeChallenges() throws {
        let s=try store();try s.ensureChallengeYear(year:2024);try apply(s,csv());XCTAssertEqual(try count(s,"challenge_assignments"),0);XCTAssertEqual(try count(s,"challenge_analysis"),0)
    }
    func testNoHistoricalJournalInboxFlooding() throws { let s=try store();try apply(s,csv());XCTAssertTrue(try s.journalInbox().isEmpty);XCTAssertEqual(try count(s,"journal_components"),0) }
    func testFormatNeverImportedOrStoredInEvidence() throws {
        let s=try store();try apply(s,csv());let record=try s.library().first!;XCTAssertNil(record.readings.first?.journalFormat)
        try apply(s,csv("Archive,Author,uid1,read,1,,2024/02/03,4,audiobook\n"));XCTAssertNil(try s.record(id:record.id).readings.first?.journalFormat)
        XCTAssertEqual(try count(s,"progress_observations"),0)
    }
    func testUserCorrectionProtectedAndExplicitlyReviewable() throws {
        let s=try store();try apply(s,csv());let id=try s.library().first!.id
        try s.edit(bookID:id,values:[.title:"My corrected title"],revision:0)
        let run=try apply(s,csv("Imported correction,Author,uid1,read,1,,2024/02/03,4,ebook\n"))
        XCTAssertEqual(run.newBooks,0);XCTAssertEqual(try s.record(id:id).book.title,"My corrected title")
        XCTAssertTrue(try s.importReviews().first { $0.field=="title" }!.userOverridden)
    }
    func testAmbiguousTitleDoesNotMergeOrDuplicate() throws {
        let s=try store();let id=try s.add(work:.init(provider:"manual",reference:"manual",title:"Archive",author:"Author"))
        let preview=try s.previewStoryGraph(csv());XCTAssertEqual(preview.count(.review),1);XCTAssertTrue(preview.candidates[0].matches.contains(id))
        let run=try s.applyImport(preview,confirmed:true);XCTAssertEqual(run.newBooks,0);XCTAssertEqual(run.newReadings,0);XCTAssertEqual(try s.pendingImportCandidates().count,1)
    }
    func testRereadsOneBookDistinctReadingInstances() throws {
        let s=try store();let run=try apply(s,csv("Archive,Author,uid1,read,2,\"2023/02/01-2023/02/03,2024/02/01-2024/02/03\",,4,ebook\n"))
        XCTAssertEqual(run.newBooks,1);XCTAssertEqual(run.newReadings,2);XCTAssertEqual(try s.library().first!.readings.count,2)
        XCTAssertTrue(try s.library().first!.readings.allSatisfy(\.historical))
    }
    func testRetryAndReorderedImportDoNotDuplicateLifecycleRecords() throws {
        let s=try store();let first=try apply(s,csv());let retry=try apply(s,csv());XCTAssertEqual(first.id,retry.id);XCTAssertEqual(try s.importHistory().count,1)
        try apply(s,csv("Archive,Author,uid1,read,1,,2024/02/03,4,paperback\n"));XCTAssertEqual(try count(s,"readings"),1)
    }
    func testUnknownDatesRemainUnknownAndPagesAreNotManufactured() throws {
        let s=try store();try apply(s,csv("Archive,Author,uid1,read,1,,,0,ebook\n"));let reading=try s.library().first!.readings.first!
        XCTAssertNil(reading.startDate);XCTAssertNil(reading.finishDate);XCTAssertNil(reading.progress.currentPage);XCTAssertNil(reading.progress.totalPages);XCTAssertEqual(reading.rating,.noRating)
    }
    func testOnlyExplicitAcceptedFieldChangesApplied() throws {
        let s=try store();try apply(s,csv());let id=try s.library().first!.id
        try apply(s,csv("Archive Revised,Author,uid1,read,1,,2024/02/04,5,ebook\n"));let reviews=try s.importReviews();XCTAssertEqual(reviews.count,3)
        try s.decideImport(id:reviews.first{$0.field=="finish_date"}!.id,accept:true)
        let record=try s.record(id:id);XCTAssertEqual(record.book.title,"Archive");XCTAssertEqual(record.readings[0].rating,.stars(4));XCTAssertEqual(record.readings[0].finishDate?.isoString,"2024-02-04")
        XCTAssertTrue(try s.xpAwards().isEmpty);XCTAssertTrue(try s.journalInbox().isEmpty)
    }
    func testRejectedFingerprintSuppressedUntilMaterialEvidenceChanges() throws {
        let s=try store();try apply(s,csv());let changed=csv("Archive Revised,Author,uid1,read,1,,2024/02/03,4,ebook\n")
        try apply(s,changed);try s.decideImport(id:s.importReviews().first!.id,accept:false)
        XCTAssertEqual(try s.previewStoryGraph(csv("Archive Revised,Author,uid1,read,1,,2024/02/03,4,paperback\n")).count(.unchanged),1)
        try apply(s,csv("Archive Different,Author,uid1,read,1,,2024/02/03,4,ebook\n"));XCTAssertEqual(try s.importReviews().count,1)
    }
    func testAccurateCommittedHistoryAndCancelledPreview() throws {
        let s=try store();let preview=try s.previewStoryGraph(csv());XCTAssertTrue(try s.importHistory().isEmpty)
        XCTAssertThrowsError(try s.applyImport(preview,confirmed:false));XCTAssertEqual(try s.bookCount(),0)
        let result=try s.applyImport(preview,confirmed:true);XCTAssertEqual(result.rows,1);XCTAssertEqual(result.newBooks,1);XCTAssertEqual(result.review,0);XCTAssertEqual(try s.importHistory().first!.id,result.id)
    }
    func testMalformedUnsupportedCSVFailsWithoutMutation() throws {
        let s=try store();for data in [Data("not,csv\na,b,c".utf8),Data((header+"\"unclosed").utf8),Data("Title,Authors,Read Status\nBad,Author,read,extra".utf8),Data([0xff])] {
            XCTAssertThrowsError(try s.previewStoryGraph(data));XCTAssertEqual(try s.bookCount(),0);XCTAssertTrue(try s.importHistory().isEmpty)
        }
    }
    func testAtomicRollbackWhenOutboxFails() throws {
        let s=try store();let preview=try s.previewStoryGraph(csv());try s.queue.write { try $0.execute(sql:"CREATE TRIGGER fail_import BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'fixture failure');END") }
        XCTAssertThrowsError(try s.applyImport(preview,confirmed:true));XCTAssertEqual(try count(s,"books"),0);XCTAssertEqual(try count(s,"readings"),0);XCTAssertEqual(try count(s,"import_occurrences"),0);XCTAssertEqual(try count(s,"import_runs"),0)
    }
    func testStalePreviewAndStaleProposalCannotOverwrite() throws {
        let s=try store();let preview=try s.previewStoryGraph(csv());_ = try s.add(work:.init(provider:"manual",reference:"a",title:"Other",author:"Author"))
        XCTAssertThrowsError(try s.applyImport(preview,confirmed:true))
        try apply(s,csv());let book=try s.library(query:"Archive").first!;try apply(s,csv("Archive Revised,Author,uid1,read,1,,2024/02/03,4,ebook\n"));let review=try s.importReviews().first!
        try s.edit(bookID:book.id,values:[.title:"Another human correction"],revision:book.revision)
        XCTAssertThrowsError(try s.decideImport(id:review.id,accept:true));XCTAssertEqual(try s.record(id:book.id).book.title,"Another human correction")
    }
    func testToReadCreatesNoFakeReadingAndDNFDoesNotCountAsRead() throws {
        let s=try store();let run=try apply(s,csv("Future,Author,future,to-read,0,,,,ebook\nStopped,Author,stopped,did-not-finish,0,,,,ebook\n"))
        XCTAssertEqual(run.newBooks,2);XCTAssertEqual(run.newReadings,1);XCTAssertTrue(try s.library(query:"Future").first!.readings.isEmpty);XCTAssertEqual(try s.library(view:.read).count,0)
    }
    func testQuotedUnicodeBOMAndMultilineCellsParsedWithoutFormulaExecution() throws {
        let data=Data(("\u{FEFF}"+header+"\"Archive, 雪\",Author,uid1,read,1,,,0,\"ignored\nformat\"\r\n").utf8)
        let rows=try StoryGraphAdapter.rows(data);XCTAssertEqual(rows[0].title,"Archive, 雪");XCTAssertTrue(rows[0].issues.isEmpty)
    }
    func testHalfStarAndAmbiguousDateRequireReviewWithoutRounding() throws {
        let s=try store();let preview=try s.previewStoryGraph(csv("Archive,Author,uid1,read,1,,03/04/2024,3.5,ebook\n"));XCTAssertEqual(preview.count(.review),1);XCTAssertEqual(preview.candidates[0].row.rating,.unknown);XCTAssertNil(preview.candidates[0].row.finishes[0]);try s.applyImport(preview,confirmed:true);XCTAssertEqual(try s.bookCount(),0)
    }
    func testPendingEvidenceAndHistorySurviveReopeningAndAreOwnerScoped() throws {
        let path=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".sqlite").path;defer { try? FileManager.default.removeItem(atPath:path) }
        let owner=UUID();let s=try LocalStore(path:path,ownerID:owner);try apply(s,csv("Archive,Author,uid1,read,1,,03/04/2024,3.5,ebook\n"))
        let reopened=try LocalStore(path:path,ownerID:owner);XCTAssertEqual(try reopened.pendingImportCandidates().count,1);XCTAssertEqual(try reopened.importHistory().count,1)
        let other=try LocalStore(path:path,ownerID:UUID());XCTAssertTrue(try other.importHistory().isEmpty);XCTAssertTrue(try other.pendingImportCandidates().isEmpty)
    }
    func testExplicitExistingReadingLinkPreservesFormatOriginAndNoDuplicate() throws {
        let s=try store();let book=try s.add(work:.init(provider:"manual",reference:"a",title:"Archive",author:"Author"))
        let reading=try s.recordCompleted(bookID:book,editionID:nil,date:try ReadingDate(year:2024,month:2,day:3),rating:.stars(4))
        try s.editReading(readingID:reading,start:nil,finish:try ReadingDate(year:2024,month:2,day:3),rating:.stars(4),genre:nil,format:.paperback,revision:0)
        let legitimateAwards=try s.xpAwards()
        try apply(s,csv());let candidate=try s.pendingImportCandidates().first!
        try s.linkImportCandidate(id:candidate.id,bookID:book,readingIDs:[reading],confirmed:true)
        XCTAssertEqual(try s.record(id:book).readings.count,1);XCTAssertEqual(try s.record(id:book).readings.first!.journalFormat,.paperback)
        XCTAssertTrue(try s.importReviews().isEmpty,"An exact explicitly linked reading needs no correction");XCTAssertEqual(try s.xpAwards(),legitimateAwards,"Import preserves existing legitimate XP and adds no award")
    }
    func testKeptIncompleteRowSuppressionIgnoresPositionAndFormatButNotChangedEvidence() throws {
        let s=try store();let data=csv("Archive,Author,uid1,read,1,,03/04/2024,3.5,ebook\n")
        try apply(s,data);try s.skipImportCandidate(id:s.pendingImportCandidates().first!.id,confirmed:true)
        let shifted=csv("Other,Another,other,to-read,0,,,,ebook\nArchive,Author,uid1,read,1,,03/04/2024,3.5,paperback\n")
        let preview=try s.previewStoryGraph(shifted);XCTAssertEqual(preview.candidates[1].group,.unchanged)
        XCTAssertEqual(try s.previewStoryGraph(csv("Archive,Author,uid1,read,1,,04/05/2024,3.5,ebook\n")).count(.review),1)
    }
    func testImportedActiveReadingHasNoRetroactivityButFutureGenuineActivityWorks() throws {
        let s=try store();_ = try s.currentQuests();try apply(s,csv("Ongoing,Author,active,currently-reading,0,,,,ebook\n"))
        let reading=try s.library().first!.readings.first!;XCTAssertFalse(reading.historical);XCTAssertTrue(try s.xpAwards().isEmpty);XCTAssertEqual(try count(s,"gamification_activity"),0)
        _ = try s.update(readingID:reading.id,value:.pages(current:10),revision:0,observationID:UUID());XCTAssertGreaterThan(try count(s,"gamification_activity"),0)
    }
    func testImportedDNFOnlyExplicitResumeActivatesFutureLiveCommands() throws {
        let s=try store();try apply(s,csv("Stopped,Author,dnf,did-not-finish,0,,,,ebook\n"));let reading=try s.library().first!.readings.first!
        XCTAssertTrue(reading.historical);XCTAssertEqual(reading.status,.dnf);XCTAssertTrue(try s.xpAwards().isEmpty)
        try s.resume(readingID:reading.id,revision:0);let resumed=try s.library().first!.readings.first!;XCTAssertFalse(resumed.historical);XCTAssertNil(resumed.progress.currentPage)
        XCTAssertTrue(try s.xpAwards().isEmpty);XCTAssertTrue(try s.journalInbox().isEmpty);XCTAssertEqual(try count(s,"gamification_activity"),0)
        try s.finish(readingID:reading.id,confirmed:true,date:nil,revision:resumed.revision);XCTAssertFalse(try s.xpAwards().isEmpty);XCTAssertEqual(try s.journalInbox().count,1)
    }
    func testWithinFileDuplicatePreviewAndContradictoryIdentityAreConservative() throws {
        let s=try store();let line="Archive,Author,uid1,read,1,,2024/02/03,4,ebook\n"
        let preview=try s.previewStoryGraph(csv(line+line));XCTAssertEqual(preview.count(.newBooks),1);XCTAssertEqual(preview.count(.unchanged),1)
        let run=try s.applyImport(preview,confirmed:true);XCTAssertEqual(run.newBooks,1);XCTAssertEqual(run.newReadings,1)
        let other=try store();let conflict=try other.previewStoryGraph(csv(line+"Different title,Author,uid1,read,1,,2024/02/03,4,ebook\n"))
        XCTAssertEqual(conflict.count(.review),2);try other.applyImport(conflict,confirmed:true);XCTAssertEqual(try other.bookCount(),0)
    }
    func testReviewShowsLiveCurrentValueAndRejectsAnUnseenLaterEdit() throws {
        let s=try store();try apply(s,csv());let book=try s.library().first!;try apply(s,csv("Archive Revised,Author,uid1,read,1,,2024/02/03,4,ebook\n"))
        try s.edit(bookID:book.id,values:[.title:"My current title"],revision:book.revision)
        let displayed=try s.importReviews().first!;XCTAssertEqual(displayed.current,"My current title")
        try s.edit(bookID:book.id,values:[.title:"A later edit"],revision:s.record(id:book.id).revision)
        XCTAssertThrowsError(try s.decideImport(id:displayed.id,accept:true,currentFingerprint:displayed.currentFingerprint))
        let refreshed=try s.importReviews().first!;try s.decideImport(id:refreshed.id,accept:true,currentFingerprint:refreshed.currentFingerprint)
        XCTAssertEqual(try s.record(id:book.id).book.title,"Archive Revised")
    }
}
