import XCTest
@testable import ReadingDomain

final class SeriesAndJournalTests: XCTestCase {
    func testAmbiguousSeriesReturnsUnknown() {
        for evidence in [
            SeriesStatusEvidence(),
            .init(hasUnreadIncludedPublished:false,allIncludedConfirmedRead:true),
            .init(allIncludedPublishedRead:true,confirmedComplete:false),
            .init(hasAnnouncedOrExpectedFutureEntry:true),
            .init(allIncludedConfirmedRead:false,confirmedComplete:true)
        ] {
            XCTAssertEqual(SeriesRules.effectiveStatus(override:nil,evidence:evidence),.unknown)
        }
    }
    func testWaitingRequiresReadPublishedEntriesAndPositiveFutureEvidence() {
        XCTAssertEqual(SeriesRules.effectiveStatus(override:nil,
            evidence:.init(allIncludedPublishedRead:true,hasAnnouncedOrExpectedFutureEntry:true)),.waiting)
        XCTAssertEqual(SeriesRules.effectiveStatus(override:nil,
            evidence:.init(allIncludedPublishedRead:true,knownOngoing:true)),.waiting)
        XCTAssertEqual(SeriesRules.effectiveStatus(override:nil,
            evidence:.init(allIncludedPublishedRead:false,knownOngoing:true)),.unknown)
    }
    func testActiveCompletedAndOverride() {
        XCTAssertEqual(SeriesRules.effectiveStatus(override:nil,evidence:.init(hasUnreadIncludedPublished:true)),.active)
        XCTAssertEqual(SeriesRules.effectiveStatus(override:nil,
            evidence:.init(allIncludedConfirmedRead:true,confirmedComplete:true)),.completed)
        for override in [SeriesStatus.active,.waiting,.completed,.abandoned,.unknown] {
            XCTAssertEqual(SeriesRules.effectiveStatus(override:override,evidence:.init()),override)
        }
    }
    func testJournalCompletionGuardDoesNotRequireAllComponentsToBeRead() {
        XCTAssertTrue(JournalRules.mayGenerateCompletionWork(status:.currentlyReading,origin:.user))
        XCTAssertFalse(JournalRules.inCompletionFlow(status:.currentlyReading))
        XCTAssertFalse(JournalRules.mayGenerateCompletionWork(status:.dnf,origin:.user))
        XCTAssertFalse(JournalRules.inCompletionFlow(status:.dnf))
        XCTAssertFalse(JournalRules.mayGenerateCompletionWork(status:.read,origin:.historicalImport))
    }
}
