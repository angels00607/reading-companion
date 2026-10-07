import XCTest
import Foundation
import GRDB
import ReadingDomain
@testable import ReadingData

private final class Phase7Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = ISO8601DateFormatter().date(from:"2026-10-05T12:00:00Z")!
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ raw: String) { lock.lock(); defer { lock.unlock() }; value = ISO8601DateFormatter().date(from:raw)! }
}
final class Phase7ProductionTests: XCTestCase {
    private let zone = TimeZone(secondsFromGMT:0)!
    private func store(_ clock:Phase7Clock, path:String = ":memory:", owner:UUID = UUID()) throws -> LocalStore { try LocalStore(path:path,ownerID:owner,gamificationNow:{ clock.now() },timeZone:zone) }
    private func reading(_ s:LocalStore, mode:ProgressMode = .page) throws -> (UUID,UUID) {
        let book = try s.add(work:.init(provider:"manual",reference:UUID().uuidString,title:"A reading journey",author:"Author"),choice:.addAnyway)
        return (book,try s.start(bookID:book,editionID:nil,mode:mode,date:nil))
    }
    func testFlowACleanLaunchAndUnseededVolume() throws {
        let s = try store(Phase7Clock())
        XCTAssertTrue(try s.xpAwards().isEmpty)
        let quests = try s.currentQuests()
        for c in QuestCadence.allCases { XCTAssertEqual(quests.filter { $0.cadence == c }.count,c.activeCount) }
        XCTAssertTrue(quests.allSatisfy { $0.progress == 0 && !$0.isComplete })
        XCTAssertTrue(try s.xpAwards().isEmpty)
        XCTAssertEqual(try s.currentQuests(),quests)
    }
    func testFlowBLiveEventCompletionReplayAndReopen() throws {
        let clock = Phase7Clock(), owner = UUID(), url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".sqlite")
        defer { try? FileManager.default.removeItem(at:url) }
        let s = try store(clock,path:url.path,owner:owner)
        _ = try s.currentQuests(); let (_,r) = try reading(s); let observation = UUID()
        _ = try s.update(readingID:r,value:.pages(current:10),revision:0,observationID:observation)
        let after = try s.currentQuests(), awards = try s.xpAwards()
        XCTAssertTrue(after.contains { $0.templateKey == "progress.record" && $0.isComplete })
        XCTAssertEqual(awards.filter { $0.semanticKey.hasPrefix("quest:") }.count,after.filter(\.isComplete).count)
        _ = try s.update(readingID:r,value:.pages(current:10),revision:0,observationID:observation)
        XCTAssertEqual(try s.xpAwards().count,awards.count)
        let reopened = try store(clock,path:url.path,owner:owner)
        XCTAssertEqual(try reopened.currentQuests(),after)
        XCTAssertEqual(try reopened.xpAwards().count,awards.count)
    }
    func testFlowsCDCurrentPeriodSlotQuotaAndISOWeekRollover() throws {
        let clock = Phase7Clock(),s = try store(clock)
        let first = try s.currentQuests(), daily = first.filter { $0.cadence == .daily }
        try s.rerollQuest(daily[1].id)
        let replaced = try s.currentQuests().filter { $0.cadence == .daily }
        XCTAssertTrue(replaced.contains { $0.id == daily[0].id }); XCTAssertFalse(replaced.contains { $0.id == daily[1].id })
        XCTAssertFalse(replaced.contains { $0.templateKey == daily[1].templateKey })
        XCTAssertFalse(try s.rerollAvailable(.daily))
        XCTAssertThrowsError(try s.rerollQuest(replaced.first!.id))
        XCTAssertThrowsError(try s.rerollQuest(first.first { $0.cadence == .monthly }!.id))
        let weekly = first.first { $0.cadence == .weekly }!; try s.rerollQuest(weekly.id)
        clock.set("2026-10-06T12:00:00Z")
        let next = try s.currentQuests()
        XCTAssertEqual(next.filter { $0.cadence == .daily }.count,2)
        XCTAssertTrue(next.filter { $0.cadence == .daily }.allSatisfy { $0.periodKey == "2026-10-06" })
        XCTAssertTrue(try s.rerollAvailable(.daily)); XCTAssertFalse(try s.rerollAvailable(.weekly))
        XCTAssertTrue(try s.quests().contains { $0.id == daily[1].id && $0.rerolledAt != nil })
        clock.set("2026-10-12T12:00:00Z")
        XCTAssertTrue(try s.currentQuests().filter { $0.cadence == .weekly }.allSatisfy { $0.periodKey == "2026-W42" })
        XCTAssertTrue(try s.rerollAvailable(.weekly))
        XCTAssertTrue(try s.quests().contains { $0.id == weekly.id && $0.rerolledAt != nil })
    }
    func testFlowECooldownUsesCalendarNotInsertionOrder() throws {
        let t = QuestCatalog.templates.first!, q = QuestInstance(templateKey:t.key,cadence:.daily,periodKey:"2026-10-05",title:t.title,unit:t.unit,target:1)
        XCTAssertFalse(QuestPeriod.cooldownAllows(t,cadence:.daily,periodKey:"2026-10-06",history:[q],timeZone:zone))
        XCTAssertTrue(QuestPeriod.cooldownAllows(t,cadence:.daily,periodKey:"2026-10-07",history:[q],timeZone:zone))
        let clock = Phase7Clock(),s = try store(clock); _ = try s.currentQuests()
        clock.set("2026-10-06T12:00:00Z"); XCTAssertFalse(try s.currentQuests().contains { $0.cadence == .daily && $0.templateKey == t.key })
        clock.set("2026-10-07T12:00:00Z"); XCTAssertTrue(try s.currentQuests().contains { $0.cadence == .daily && $0.templateKey == t.key })
    }
    func testFlowFAutomaticCatalogAchievementsAndIdempotency() throws {
        let clock = Phase7Clock(),s = try store(clock)
        for n in 0..<10 {
            clock.set(String(format:"2026-10-%02dT12:00:00Z",5+n))
            let (_,r) = try reading(s)
            _ = try s.update(readingID:r,value:.pages(current:20),revision:0)
            try s.finish(readingID:r,confirmed:true,date:nil,revision:1)
            try s.saveBookReview(readingID:r,draft:.init(summary:"My review",pageCount:20,rating:.noRating,format:.paperback,start:nil,finish:nil))
            try s.markBookReviewCopied(readingID:r)
        }
        _ = try s.currentQuests()
        let progress = try s.achievementProgress()
        for key in ["books.first","books.ten","journal.five","quests.ten"] { XCTAssertTrue(progress.first { $0.definition.key == key }!.isUnlocked,key) }
        XCTAssertEqual(progress.first { $0.definition.key == "books.ten" }?.progress,10)
        let before = try s.xpAwards(); _ = try s.currentQuests()
        XCTAssertEqual(try s.xpAwards().count,before.count)
        for a in progress where a.isUnlocked && a.definition.xp > 0 { XCTAssertEqual(before.filter { $0.semanticKey == "achievement:"+a.definition.key }.count,1) }
        XCTAssertEqual(progress.first { $0.definition.key == "level.five" }!.isUnlocked,GamificationBalance.level(totalXP:before.reduce(0) { $0+$1.amount }) >= 5)
    }
    func testFlowGRealLevelUnlockAndEssentialsRemainAvailable() throws {
        let s = try store(Phase7Clock())
        XCTAssertEqual(try s.cosmeticStates()["accent.berry"],.locked)
        for _ in 0..<5 { let (_,r) = try reading(s); try s.finish(readingID:r,confirmed:true,date:nil,revision:0) }
        XCTAssertGreaterThanOrEqual(GamificationBalance.level(totalXP:try s.xpAwards().reduce(0) { $0+$1.amount }),2)
        XCTAssertEqual(try s.cosmeticStates()["accent.berry"],.unlocked)
        XCTAssertEqual(try s.library().count,5)
    }
    func testFlowsHIJEquipmentValidationAtomicPresetAndReopen() throws {
        let clock = Phase7Clock(),owner = UUID(),url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".sqlite")
        defer { try? FileManager.default.removeItem(at:url) }
        let s = try store(clock,path:url.path,owner:owner), before = try s.cosmeticStates()
        XCTAssertThrowsError(try s.setCosmetic("accent.berry",state:.equipped))
        XCTAssertThrowsError(try s.setCosmetic("invented",state:.equipped))
        XCTAssertEqual(try s.cosmeticStates(),before)
        // A UI preview has no repository command; only Apply calls setCosmetic.
        try s.setCosmetic("theme.modern-bookish",state:.equipped)
        let reopened = try store(clock,path:url.path,owner:owner)
        XCTAssertEqual(try reopened.cosmeticStates()["theme.modern-bookish"],.equipped)
        XCTAssertEqual(try reopened.cosmeticStates()["frame.classic"],.equipped)
        XCTAssertEqual(try reopened.cosmeticStates()["background.midnight"],.equipped)
        XCTAssertEqual(try reopened.cosmeticStates()["accent.berry"],.locked)
        XCTAssertTrue(try reopened.xpAwards().isEmpty)
    }
    func testNoPercentagePagesSessionsImportOrDNFCompletion() throws {
        let s = try store(Phase7Clock()),(_,r) = try reading(s,mode:.percentage)
        _ = try s.update(readingID:r,value:.percentage(80),revision:0)
        XCTAssertEqual(try s.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM gamification_activity WHERE family='pages'") },0)
        try s.markDNF(readingID:r,revision:1)
        let b = try s.add(work:.init(provider:"import",reference:"past",title:"Past",author:"Author"))
        _ = try s.recordCompleted(bookID:b,editionID:nil,date:nil,rating:.unknown)
        XCTAssertEqual(try s.achievementProgress().first { $0.definition.key == "books.first" }?.progress,0)
        XCTAssertFalse(try s.xpAwards().contains { $0.source == .finishBook })
    }
    func testLatePeriodDayCapsAndWeekYear() {
        let late = ISO8601DateFormatter().date(from:"2026-10-31T12:00:00Z")!
        XCTAssertEqual(QuestPeriod(cadence:.monthly,now:late,timeZone:zone).availableDays,1)
        let year = ISO8601DateFormatter().date(from:"2027-01-01T12:00:00Z")!
        XCTAssertEqual(QuestPeriod(cadence:.weekly,now:year,timeZone:zone).key,"2026-W53")
        for t in QuestCatalog.templates where t.family == .frequency || t.family == .consistency {
            XCTAssertLessThanOrEqual(QuestRules.target(for:t,cadence:.daily,activity:.init(sessionsPerWeek:[999])),1)
            XCTAssertLessThanOrEqual(QuestRules.target(for:t,cadence:.weekly,activity:.init(sessionsPerWeek:[999])),7)
        }
    }
}
