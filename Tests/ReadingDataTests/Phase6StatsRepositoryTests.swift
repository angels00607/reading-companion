import XCTest
import ReadingDomain
import GRDB
@testable import ReadingData

final class Phase6StatsRepositoryTests:XCTestCase {
    private let month=StatsPeriod.month(year:2026,month:9)
    private func store() throws -> LocalStore { try .init(path:":memory:",ownerID:UUID()) }
    private func complete(_ s:LocalStore,pages:Int?=100,book:UUID?=nil,year:Int=2026,month:Int=9,rating:Rating = .unknown) throws -> (UUID,UUID) {
        let bid:UUID
        if let book { bid=book } else { bid=try s.add(work:.init(provider:"fixture",reference:UUID().uuidString,title:UUID().uuidString,author:"Fixture Author")) }
        let rid=try s.start(bookID:bid,editionID:nil,mode:pages==nil ? .percentage : .page,date:nil)
        _ = try s.update(readingID:rid,value:pages.map { try! ReadingProgress.pages(current:$0) } ?? .percentage(100),revision:0)
        let date=try ReadingDate(year:year,month:month,day:1)
        try s.finish(readingID:rid,confirmed:true,date:date,revision:1)
        try s.editReading(readingID:rid,start:nil,finish:date,rating:rating,genre:nil,format:nil,revision:2)
        return (bid,rid)
    }
    func testPagesComeOnlyFromResolvedOriginalPageObservations() throws {
        let s=try store(); _=try complete(s,pages:74); _=try complete(s,pages:nil)
        let stats=try s.stats(period:month); XCTAssertEqual(stats.books,2); XCTAssertEqual(stats.pages.known,74); XCTAssertFalse(stats.pages.complete)
        XCTAssertNil(stats.readingDays.known)
    }
    func testHistoricalEditionAndJournalTotalsCannotFabricatePagesOrDays() throws {
        let s=try store()
        let b=try s.add(work:.init(provider:"fixture",reference:"historical",title:"Historical",author:"Author"),edition:.init(provider:"fixture",reference:"edition",pageCount:400))
        let e=try XCTUnwrap(s.record(id:b).editions.first)
        let r=try s.recordCompleted(bookID:b,editionID:e.id,date:ReadingDate(year:2026,month:9,day:30),rating:.noRating)
        try s.editReading(readingID:r,start:ReadingDate(year:2026,month:9,day:1),finish:ReadingDate(year:2026,month:9,day:30),rating:.noRating,genre:nil,format:nil,revision:0)
        let stats=try s.stats(period:month); XCTAssertEqual(stats.books,1); XCTAssertNil(stats.pages.known); XCTAssertNil(stats.readingDays.known)
        XCTAssertTrue(try s.journalInbox().isEmpty)
    }
    func testDNFAllMetricsExcludeRetainedProgressAndActivity() throws {
        let s=try store(),b=try s.add(work:.init(provider:"fixture",reference:"dnf",title:"DNF",author:"Author"))
        let r=try s.start(bookID:b,editionID:nil,date:nil)
        _=try s.update(readingID:r,value:.pages(current:250),revision:0)
        try s.recordReadingActivity(readingID:r,date:ReadingDate(year:2026,month:9,day:1),sourceReference:"User explicitly recorded reading date")
        try s.markDNF(readingID:r,revision:1)
        let st=try s.stats(period:.lifetime); XCTAssertEqual(st.books,0); XCTAssertEqual(st.pages.known,0); XCTAssertEqual(st.readingDays.known,0)
        XCTAssertEqual(try s.record(id:b).latest?.progress.currentPage,250)
    }
    func testRereadDoesNotDuplicateBookAndFormatsRemainIndependent() throws {
        let s=try store(),first=try complete(s),second=try complete(s,book:first.0,year:2027)
        try s.editReading(readingID:first.1,start:nil,finish:ReadingDate(year:2026,month:9,day:1),rating:.stars(5),genre:"Fantasy",format:.paperback,revision:3)
        try s.editReading(readingID:second.1,start:nil,finish:ReadingDate(year:2027,month:9,day:1),rating:.noRating,genre:nil,format:.audiobook,revision:3)
        XCTAssertEqual(try s.bookCount(),1); XCTAssertEqual(try s.stats(period:.year(2026)).books,1); XCTAssertEqual(try s.stats(period:.year(2027)).books,1)
        let life=try s.stats(period:.lifetime); XCTAssertEqual(life.books,2); XCTAssertEqual(life.formats.count,2); XCTAssertEqual(life.averageRating,5)
    }
    func testManualSelectionsPersistAndYearRequiresMonthlyChoice() throws {
        let s=try store(),a=try complete(s,rating:.stars(3)),b=try complete(s,rating:.stars(5))
        XCTAssertNil(try s.stats(period:month).selection)
        XCTAssertThrowsError(try s.selectBestBook(period:.year(2026),readingID:b.1,expectedRevision:0))
        try s.selectBestBook(period:month,readingID:a.1,expectedRevision:0)
        XCTAssertEqual(try s.stats(period:.year(2026)).candidates.map(\.id),[a.1])
        XCTAssertNil(try s.stats(period:.year(2026)).selection)
        try s.selectBestBook(period:.year(2026),readingID:a.1,expectedRevision:0)
        XCTAssertEqual(try s.stats(period:.year(2026)).selected?.id,a.1)
    }
    func testEligibilityCorrectionPreservesManualMonthAndYearForReview() throws {
        let s=try store(),a=try complete(s)
        try s.selectBestBook(period:month,readingID:a.1,expectedRevision:0)
        try s.selectBestBook(period:.year(2026),readingID:a.1,expectedRevision:0)
        try s.editReading(readingID:a.1,start:nil,finish:ReadingDate(year:2027,month:1,day:1),rating:.stars(5),genre:"Corrected",format:.ebook,revision:3)
        XCTAssertTrue(try s.stats(period:month).selectionNeedsReview); XCTAssertEqual(try s.stats(period:month).selected?.id,a.1)
        XCTAssertTrue(try s.stats(period:.year(2026)).selectionNeedsReview); XCTAssertEqual(try s.stats(period:.year(2026)).books,0)
    }
    func testChangingMonthlyChoiceDoesNotSilentlyReplaceYear() throws {
        let s=try store(),a=try complete(s),b=try complete(s)
        try s.selectBestBook(period:month,readingID:a.1,expectedRevision:0); try s.selectBestBook(period:.year(2026),readingID:a.1,expectedRevision:0)
        try s.selectBestBook(period:month,readingID:b.1,expectedRevision:1)
        let year=try s.stats(period:.year(2026)); XCTAssertEqual(year.selected?.id,a.1); XCTAssertTrue(year.selectionNeedsReview)
    }
    func testSelectionOutboxAtomicStaleRevisionAndExplicitClear() throws {
        let s=try store(),a=try complete(s)
        try s.selectBestBook(period:month,readingID:a.1,expectedRevision:0)
        XCTAssertThrowsError(try s.selectBestBook(period:month,readingID:nil,expectedRevision:0))
        try s.selectBestBook(period:month,readingID:nil,expectedRevision:1)
        let st=try s.stats(period:month); XCTAssertNil(st.selection?.readingID); XCTAssertEqual(st.selection?.revision,2)
        let commands=try s.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM outbox WHERE kind='stats.best_book.select'") }; XCTAssertEqual(commands,2)
    }
    func testActivityDeduplicatesDatesRequiresExplicitSourceAndExcludesOtherOwner() throws {
        let s=try store(),a=try complete(s),date=try ReadingDate(year:2026,month:9,day:1)
        XCTAssertThrowsError(try s.recordReadingActivity(readingID:a.1,date:date,sourceReference:""))
        for _ in 0..<2 { try s.recordReadingActivity(readingID:a.1,date:date,sourceReference:"Explicit user date") }
        XCTAssertEqual(try s.stats(period:month).readingDays.known,1)
        let commands=try s.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM outbox WHERE kind='stats.activity.record'") }; XCTAssertEqual(commands,1)
        XCTAssertThrowsError(try s.selectBestBook(period:month,readingID:UUID(),expectedRevision:0))
    }
    func testOfflineReopenAndJournalProjectionShareManualSelection() throws {
        let path=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".sqlite").path,owner=UUID()
        defer { try? FileManager.default.removeItem(atPath:path) }
        let s=try LocalStore(path:path,ownerID:owner),a=try complete(s)
        try s.selectBestBook(period:month,readingID:a.1,expectedRevision:0)
        let reopened=try LocalStore(path:path,ownerID:owner)
        XCTAssertEqual(try reopened.stats(period:month).selected?.id,a.1)
        XCTAssertEqual(try reopened.stats(period:.volume(startYear:2026)).books,try reopened.stats(period:.year(2026)).books)
        let other=try LocalStore(path:path,ownerID:UUID()); XCTAssertEqual(try other.stats(period:.lifetime).books,0); XCTAssertNil(try other.stats(period:month).selection)
    }
}
