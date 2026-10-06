import XCTest
@testable import ReadingDomain

final class Phase6StatsTests:XCTestCase {
    private let month=StatsPeriod.month(year:2026,month:9)
    private func date(_ year:Int=2026,_ month:Int=9,_ day:Int=1) -> ReadingDate { try! .init(year:year,month:month,day:day) }
    private func fact(_ finish:ReadingDate?,book:UUID=UUID(),status:ReadingStatus = .read,rating:Rating = .unknown,pages:Int?=nil,complete:Bool=false,genre:String?=nil,format:JournalFormat?=nil,days:[ReadingDate]=[]) -> StatsReading {
        .init(id:UUID(),bookID:book,title:"Fixture",status:status,finish:finish,rating:rating,genre:genre,format:format,observedPages:pages,pageCoverageComplete:complete,activityDates:days)
    }
    private func snapshot(_ items:[StatsReading],_ period:StatsPeriod?=nil,_ choices:[BestBookSelection]=[]) -> StatsSnapshot { StatsRules.snapshot(period:period ?? month,readings:items,selections:choices) }
    func testMonthYearLifetimeAndUnknownDates() {
        let a=fact(date()),b=fact(date(2027)),c=fact(nil)
        XCTAssertEqual(snapshot([a,b,c]).books,1)
        XCTAssertEqual(snapshot([a,b,c],.year(2027)).books,1)
        XCTAssertEqual(snapshot([a,b,c],.lifetime).books,3)
        XCTAssertEqual(snapshot([a,b,c]).undatedCompletions,1)
    }
    func testDNFExcludedFromEveryMetricAndPool() {
        let dnf=fact(date(),status:.dnf,rating:.stars(5),pages:250,complete:true,genre:"Fantasy",format:.ebook,days:[date()])
        let s=snapshot([dnf]); XCTAssertEqual(s.books,0); XCTAssertEqual(s.pages.known,0); XCTAssertEqual(s.readingDays.known,0)
        XCTAssertNil(s.averageRating); XCTAssertTrue(s.genres.isEmpty); XCTAssertTrue(s.formats.isEmpty); XCTAssertTrue(s.candidates.isEmpty)
        XCTAssertFalse(s.time.contains { ($0.count ?? 0)>0 })
    }
    func testRereadsCountReadingInstancesAndDifferentFormats() {
        let book=UUID(),a=fact(date(),book:book,format:.paperback),b=fact(date(2027),book:book,format:.audiobook)
        XCTAssertEqual(snapshot([a,b]).books,1); XCTAssertEqual(snapshot([a,b],.year(2027)).books,1)
        let life=snapshot([a,b],.lifetime); XCTAssertEqual(life.books,2); XCTAssertEqual(life.rereads,1)
        XCTAssertEqual(Set(life.formats.map(\.label)),Set(["Paperback","Audiobook"]))
    }
    func testUnknownPagesAreNotZeroAndPartialSubtotalIsRetained() {
        let unknown=fact(date()),known=fact(date(),pages:74,complete:true)
        XCTAssertNil(snapshot([unknown]).pages.known)
        let s=snapshot([known,unknown]); XCTAssertEqual(s.pages.known,74); XCTAssertFalse(s.pages.complete)
        XCTAssertEqual(s.pages.coveredReadings,1); XCTAssertEqual(s.pages.totalReadings,2)
        let zero=snapshot([fact(date(),pages:0,complete:true)]); XCTAssertEqual(zero.pages.known,0); XCTAssertTrue(zero.pages.complete)
    }
    func testReadingDaysUseUniqueExplicitDatesNotIntervals() {
        XCTAssertNil(snapshot([fact(date())]).readingDays.known)
        let a=fact(date(),days:[date(2026,9,1),date(2026,9,1),date(2026,9,2)]),b=fact(date(),days:[date(2026,9,2)])
        let s=snapshot([a,b]); XCTAssertEqual(s.readingDays.known,2); XCTAssertFalse(s.readingDays.complete)
    }
    func testActivityAttributedToActualDayRatherThanFinishMonth() {
        let r=fact(date(2026,10,1),days:[date(2026,9,30)])
        let s=snapshot([r]); XCTAssertEqual(s.books,0); XCTAssertEqual(s.readingDays.known,1)
    }
    func testNoRatingAndUnknownExcludedFromAverage() {
        let s=snapshot([fact(date(),rating:.stars(5)),fact(date(),rating:.stars(3)),fact(date(),rating:.noRating),fact(date())])
        XCTAssertEqual(s.averageRating,4); XCTAssertEqual(s.ratedCount,2); XCTAssertEqual(s.noRatingCount,1); XCTAssertEqual(s.unknownRatingCount,1)
        XCTAssertNil(snapshot([fact(date(),rating:.noRating)]).averageRating)
    }
    func testOneGenreAndUnknownFormatRemainExplicit() {
        let s=snapshot([fact(date(),genre:"Chosen genre"),fact(date())])
        XCTAssertEqual(s.genres.reduce(0) { $0+$1.count },2); XCTAssertEqual(s.genres.first { $0.label=="Unknown" }?.count,1)
        XCTAssertEqual(s.formats.first?.label,"Unknown")
    }
    func testManualMonthYearPoolAndInvalidChoiceRetained() {
        let a=fact(date(),rating:.stars(3)),b=fact(date(),rating:.stars(5))
        XCTAssertNil(snapshot([a,b]).selection); XCTAssertEqual(snapshot([a,b],.year(2026)).candidates.count,0)
        let choice=BestBookSelection(id:UUID(),scope:"month",period:"2026-09",readingID:a.id,revision:1)
        let yearChoice=BestBookSelection(id:UUID(),scope:"year",period:"2026",readingID:a.id,revision:1)
        XCTAssertEqual(snapshot([a,b],.year(2026),[choice]).candidates.map(\.id),[a.id])
        XCTAssertNil(snapshot([a,b],.year(2026),[choice]).selection)
        let invalid=snapshot([a,b],.year(2026),[yearChoice]); XCTAssertTrue(invalid.selectionNeedsReview); XCTAssertEqual(invalid.selected?.id,a.id)
    }
    func testTimelineDoesNotInventUndatedPlacementOrDailyPages() {
        let s=snapshot([fact(date(2026,9,5)),fact(nil)])
        XCTAssertEqual(s.time.first { $0.id=="5" }?.count,1); XCTAssertNil(s.time.first { $0.id=="6" }?.count)
        XCTAssertEqual(snapshot([fact(date(2026,9,5))]).time.first { $0.id=="6" }?.count,0)
    }
    func testPhysicalFiveYearViewUsesSameRules() {
        let s=snapshot([fact(date(2025)),fact(date(2026)),fact(date(2030)),fact(date(2031)),fact(nil)],.volume(startYear:2026))
        XCTAssertEqual(s.books,2); XCTAssertEqual(s.time.count,5); XCTAssertNil(s.selection)
    }
    func testCurrentlyReadingDoesNotCountAsCompleted() {
        let s=snapshot([fact(date(),status:.currentlyReading,days:[date()])]); XCTAssertEqual(s.books,0); XCTAssertEqual(s.readingDays.known,1)
    }
}
