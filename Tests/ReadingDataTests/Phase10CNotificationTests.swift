import XCTest
import ReadingDomain
import ReadingUI
@testable import ReadingData

final class Phase10CNotificationTests:XCTestCase {
    private func store(_ path:String=":memory:",owner:UUID=UUID()) throws->LocalStore{try LocalStore(path:path,ownerID:owner)}
    func testDefaultsPersistenceOwnerIsolationAndIndividualToggles() throws {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".sqlite"),owner=UUID();defer{try? FileManager.default.removeItem(at:url)}
        let first=try store(url.path,owner:owner),defaults=try first.notificationPreferences()
        XCTAssertTrue(defaults.seriesReleases);XCTAssertTrue(defaults.releaseDateChanges);XCTAssertTrue(defaults.importAndSystem)
        XCTAssertFalse(defaults.challenges);XCTAssertFalse(defaults.journal);XCTAssertFalse(defaults.quests);XCTAssertNil(defaults.achievementsAndLevels)
        for category in NotificationCategory.allCases { try first.setNotificationPreference(category,enabled:true) }
        let reopened=try store(url.path,owner:owner);for category in NotificationCategory.allCases{XCTAssertTrue(try reopened.notificationPreferences().enabled(category))}
        let other=try store(url.path,owner:UUID());XCTAssertFalse(try other.notificationPreferences().challenges);XCTAssertNil(try other.notificationPreferences().achievementsAndLevels)
    }
    func testExactButUnverifiedReleaseDoesNotSchedule() async throws {
        let s=try store(),series=ReadingSeries(ownerID:s.ownerID,name:"Unverified Series")
        let entry=SeriesEntry(seriesID:series.id,bookID:nil,title:"Future Book",position:1,kind:.main,publication:.announced,release:.exact(try ReadingDate(year:2099,month:4,day:3)))
        try s.saveSeries(series,entries:[entry])
        XCTAssertTrue(try s.verifiedNotificationEvents(after:try ReadingDate(year:2098,month:1,day:1)).isEmpty)
        let delivery=MockNotificationDelivery(status:.authorized),coordinator=NotificationCoordinator(repository:s,delivery:delivery,today:{try! ReadingDate(year:2098,month:1,day:1)})
        await coordinator.reconcile()
        let batches=await delivery.batches(for:.seriesReleases)
        XCTAssertEqual(batches.last?.count,0)
    }
    func testAuthorizationIsNeverRequestedByInitializationOrReconciliation() async throws {
        let delivery=MockNotificationDelivery(status:.notDetermined),coordinator=NotificationCoordinator(repository:try store(),delivery:delivery)
        await coordinator.reconcile();let before=await delivery.requests;XCTAssertEqual(before,0)
        let authorization=await coordinator.requestAuthorization(),after=await delivery.requests;XCTAssertEqual(authorization,.authorized);XCTAssertEqual(after,1)
    }
    func testUnavailableDeliveryIsGracefulAndDisablingDoesNotChangeAttention() async throws {
        let s=try store(),attention=try s.createAttention(.init(category:.journal,priority:.required,entityID:UUID(),reason:"test",title:"Review",detail:"Required work"))
        let delivery=MockNotificationDelivery(status:.unavailable),coordinator=NotificationCoordinator(repository:s,delivery:delivery)
        try s.setNotificationPreference(.journal,enabled:false);await coordinator.reconcile()
        let requests=await delivery.requests
        XCTAssertEqual(try s.unresolvedAttentionCount(),1);XCTAssertEqual(try s.unresolvedAttention().first?.id,attention.id);XCTAssertEqual(requests,0)
    }
    func testHistoricalReadingCreatesNoNotificationEvent() throws {
        let s=try store(),book=try s.add(work:.init(provider:"manual",reference:"historical",title:"Archive",author:"Reader"),choice:.addAnyway)
        _ = try s.recordCompleted(bookID:book,editionID:nil,date:try ReadingDate(year:2020,month:1,day:1),rating:.noRating)
        XCTAssertTrue(try s.verifiedNotificationEvents(after:try ReadingDate(year:2019,month:1,day:1)).isEmpty)
    }
}

private actor MockNotificationDelivery:NotificationDeliveryService {
    private var status:NotificationAuthorizationState;private(set)var requests=0
    private var recorded:[NotificationCategory:[[VerifiedNotificationEvent]]]=[:]
    init(status:NotificationAuthorizationState){self.status=status}
    func authorizationStatus() async->NotificationAuthorizationState{status}
    func requestAuthorization() async->NotificationAuthorizationState{requests += 1;if status == .notDetermined{status = .authorized};return status}
    func replacePending(category:NotificationCategory,events:[VerifiedNotificationEvent]) async throws{recorded[category,default:[]].append(events)}
    func batches(for category:NotificationCategory)->[[VerifiedNotificationEvent]]{recorded[category] ?? []}
}
