import XCTest
@testable import ReadingDomain

final class Phase4SeriesTests: XCTestCase {
    private let owner = UUID(), seriesID = UUID()
    private func entry(_ position: String, _ state: PublicationState = .published, read: Bool = false,
                       included: Bool = true, tracker: Bool = true, kind: SeriesEntryKind = .main) -> SeriesEntry {
        SeriesEntry(seriesID: seriesID, bookID: UUID(), title: "Book \(position)", position: Decimal(string: position)!, kind: kind,
                    publication: state, release: .unknown, included: included, includedInTracker: tracker, isRead: read)
    }
    func testFractionalPositionsSortNumericallyAndDoNotImplyKind() {
        let values = [entry("2"), entry("1.5", kind: .main), entry("0.5", kind: .main), entry("1")]
        XCTAssertEqual(SeriesRules.ordered(values).map { NSDecimalNumber(decimal: $0.position).stringValue }, ["0.5","1","1.5","2"])
        XCTAssertEqual(values[1].kind, .main)
    }
    func testUnconfirmedExcludedAndUnknownTotalPreserved() {
        let values = [entry("1"), entry("2"), entry("3", .unconfirmed)]
        XCTAssertEqual(SeriesRules.confirmedTotal(values), 2)
        let series = ReadingSeries(ownerID: owner, name: "Unknown End", finalTotalKnown: false)
        XCTAssertFalse(series.finalTotalKnown)
    }
    func testEffectiveStatusTruthTableAndOverride() {
        XCTAssertEqual(SeriesRules.effectiveStatus(override: nil, evidence: .init(hasUnreadIncludedPublished: true)), .active)
        XCTAssertEqual(SeriesRules.effectiveStatus(override: nil, evidence: .init(allIncludedPublishedRead: true, hasAnnouncedOrExpectedFutureEntry: true)), .waiting)
        XCTAssertEqual(SeriesRules.effectiveStatus(override: nil, evidence: .init(allIncludedConfirmedRead: true, confirmedComplete: true)), .completed)
        XCTAssertEqual(SeriesRules.effectiveStatus(override: .abandoned, evidence: .init(hasUnreadIncludedPublished: true)), .abandoned)
        XCTAssertEqual(SeriesRules.effectiveStatus(override: nil, evidence: .init(allIncludedPublishedRead: true)), .unknown)
    }
    func testNextBookIsFirstIncludedUnreadPublishedEntry() {
        let values = [entry("0.5", read: true), entry("1", .published, included: false), entry("1.5", .announced), entry("2"), entry("3")]
        XCTAssertEqual(SeriesRules.nextBook(values)?.position, Decimal(2))
    }
    func testReleasePrecisionIsNotFabricated() throws {
        let exact = SeriesEntry(seriesID: seriesID, bookID: nil, title: "Exact", position: 1, kind: .main, publication: .announced, release: .exact(try ReadingDate(year: 2027, month: 4, day: 3)))
        let year = SeriesEntry(seriesID: seriesID, bookID: nil, title: "Year", position: 2, kind: .main, publication: .announced, release: .year(2028))
        let unknown = entry("3", .announced)
        if case .exact = exact.release {} else { XCTFail() }
        if case .year(2028) = year.release {} else { XCTFail() }
        if case .unknown = unknown.release {} else { XCTFail() }
    }
    func testDigitalSeriesUnlimitedAndPhysicalMappingNeverTruncates() {
        let values = (1...25).map { entry(String($0)) }
        XCTAssertEqual(SeriesRules.ordered(values).count, 25)
        XCTAssertEqual(SeriesRules.trackerMapping(entries: Array(values.prefix(5))).type, .type1)
        XCTAssertEqual(SeriesRules.trackerMapping(entries: Array(values.prefix(10))).type, .type2)
        XCTAssertEqual(SeriesRules.trackerMapping(entries: Array(values.prefix(20))).type, .type3)
        let mapping = SeriesRules.trackerMapping(entries: values)
        XCTAssertEqual(mapping.type, .type3); XCTAssertEqual(mapping.entryCount, 25); XCTAssertEqual(mapping.continuationPages, 1)
    }
}
