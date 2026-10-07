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
        let clock = Phase7Clock(), owner = UUID(), url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".sqlite")
        defer { try? FileManager.default.removeItem(at:url) }
        let s = try store(clock,path:url.path,owner:owner)
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
        let clock = Phase7Clock(), owner = UUID(), url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".sqlite")
        defer { try? FileManager.default.removeItem(at:url) }
        let s = try store(clock,path:url.path,owner:owner)
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
        let reopened = try store(clock,path:url.path,owner:owner)
        _ = try reopened.currentQuests()
        XCTAssertEqual(try reopened.xpAwards().count,before.count)
        XCTAssertEqual(try reopened.achievementProgress(),progress)
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
        try reopened.setCosmetic("frame.classic",state:.unlocked)
        XCTAssertEqual(try reopened.cosmeticStates()["frame.classic"],.unlocked)
        XCTAssertEqual(try reopened.cosmeticStates()["background.midnight"],.equipped,"Preset categories remain individually editable")
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
    func testExistingDomainFactsRemainAuthoritativeWithoutOrdinaryXPBackfill() throws {
        let s = try store(Phase7Clock())
        let b = try s.add(work:.init(provider:"legacy",reference:"live",title:"An existing reading",author:"Author"))
        let existing = try s.recordCompleted(bookID:b,editionID:nil,date:nil,rating:.noRating)
        // Simulate a pre-gamification, genuine nonhistorical domain record. Migration
        // does not manufacture an event or rewrite the ordinary XP ledger.
        try s.queue.write { try $0.execute(sql:"UPDATE readings SET historical=0 WHERE owner_id=? AND id=?",arguments:[s.ownerID.uuidString,existing.uuidString]) }
        let h = try s.add(work:.init(provider:"import",reference:"past",title:"A historical import",author:"Author"))
        _ = try s.recordCompleted(bookID:h,editionID:nil,date:nil,rating:.unknown)
        _ = try s.currentQuests()
        XCTAssertEqual(try s.achievementProgress().first { $0.definition.key == "books.ten" }?.progress,1)
        XCTAssertTrue(try s.achievementProgress().first { $0.definition.key == "books.first" }!.isUnlocked)
        XCTAssertFalse(try s.xpAwards().contains { $0.source == .finishBook || $0.source == .journalWork })
        XCTAssertTrue(try s.currentQuests().allSatisfy { $0.progress == 0 })
        XCTAssertEqual(try s.xpAwards().count,1)
    }
    func testPrePhase7HistoryAdaptsTargetsWithoutReplayingProgress() throws {
        let clock = Phase7Clock(), s = try store(clock)
        let b = try s.add(work:.init(provider:"legacy",reference:"observed",title:"Existing activity",author:"Author"))
        let r = try s.start(bookID:b,editionID:nil,mode:.page,date:nil)
        try s.queue.write { db in
            let observation = UUID().uuidString
            try db.execute(sql:"INSERT INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,previous_page,new_page,recorded_at,ordinal) VALUES(?,?,?,?,'page',0,80,'2026-10-04T12:00:00Z',1)",arguments:[s.ownerID.uuidString,observation,r.uuidString,observation])
            try db.execute(sql:"UPDATE readings SET current_page=80,revision=1 WHERE owner_id=? AND id=?",arguments:[s.ownerID.uuidString,r.uuidString])
            try db.execute(sql:"INSERT INTO reading_activity_dates(owner_id,reading_id,activity_date,source,source_reference,recorded_at) VALUES(?,?,'2026-10-04','user','legacy explicit day','2026-10-04T12:00:00Z')",arguments:[s.ownerID.uuidString,r.uuidString])
        }
        let activity = try s.queue.read { try s.adaptiveQuestActivity($0) }
        XCTAssertEqual(activity.genuinePagesPerDay,[80]); XCTAssertEqual(activity.readingDaysPerWeek,[1])
        XCTAssertTrue(activity.sessionsPerWeek.isEmpty)
        let quests = try s.currentQuests()
        XCTAssertEqual(quests.first { $0.cadence == .daily && $0.templateKey == "pages.genuine" }?.target,80)
        XCTAssertTrue(quests.allSatisfy { $0.progress == 0 }); XCTAssertTrue(try s.xpAwards().isEmpty)
        XCTAssertEqual(try s.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM gamification_activity") },0)
        let today = try ReadingDate(year:2026,month:10,day:5)
        try s.recordReadingActivity(readingID:r,date:today,sourceReference:"actual current day")
        XCTAssertTrue(try s.currentQuests().contains { $0.cadence == .daily && $0.templateKey == "frequency.reading-days" && $0.isComplete })
        let secondBook = try s.add(work:.init(provider:"legacy",reference:"second",title:"Another reading",author:"Author"))
        let second = try s.start(bookID:secondBook,editionID:nil,mode:.page,date:nil)
        let awards = try s.xpAwards()
        try s.recordReadingActivity(readingID:second,date:today,sourceReference:"same genuine date")
        XCTAssertEqual(try s.xpAwards().count,awards.count)
        XCTAssertEqual(try s.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM gamification_activity WHERE family='frequency'") },1)
        XCTAssertEqual(try s.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM reading_activity_dates WHERE activity_date='2026-10-05'") },2)
    }
    func testHistoricalAndUnresolvedHistoryCannotAdaptLiveTargets() throws {
        let s = try store(Phase7Clock())
        let b = try s.add(work:.init(provider:"import",reference:"historical",title:"Imported record",author:"Author"))
        let r = try s.recordCompleted(bookID:b,editionID:nil,date:try ReadingDate(year:2026,month:10,day:4),rating:.unknown)
        try s.recordReadingActivity(readingID:r,date:try ReadingDate(year:2026,month:10,day:4),sourceReference:"historical explicit date")
        try s.queue.write { db in
            for review in [0,1] {
                let id = UUID().uuidString
                try db.execute(sql:"INSERT INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,previous_page,new_page,recorded_at,requires_review,ordinal) VALUES(?,?,?,?,'page',0,90,'2026-10-04T12:00:00Z',?,?)",arguments:[s.ownerID.uuidString,id,r.uuidString,id,review,review+1])
            }
        }
        var activity = try s.queue.read { try s.adaptiveQuestActivity($0) }
        XCTAssertTrue(activity.genuinePagesPerDay.isEmpty); XCTAssertTrue(activity.readingDaysPerWeek.isEmpty); XCTAssertTrue(activity.completionsPerMonth.isEmpty)
        // Only the unresolved observation remains on a genuine reading.
        try s.queue.write { db in
            try db.execute(sql:"DELETE FROM progress_observations WHERE requires_review=0")
            try db.execute(sql:"DELETE FROM reading_activity_dates")
            try db.execute(sql:"UPDATE readings SET historical=0,status='currently_reading',finish_date=NULL WHERE id=?",arguments:[r.uuidString])
        }
        activity = try s.queue.read { try s.adaptiveQuestActivity($0) }
        XCTAssertTrue(activity.genuinePagesPerDay.isEmpty)
        XCTAssertFalse(try s.currentQuests().contains { $0.templateKey == "pages.genuine" })
        XCTAssertTrue(try s.xpAwards().isEmpty)
    }
    func testLatePeriodDayCapsAndWeekYear() {
        let late = ISO8601DateFormatter().date(from:"2026-10-31T12:00:00Z")!
        XCTAssertEqual(QuestPeriod(cadence:.monthly,now:late,timeZone:zone).availableDays,1)
        let year = ISO8601DateFormatter().date(from:"2027-01-01T12:00:00Z")!
        XCTAssertEqual(QuestPeriod(cadence:.weekly,now:year,timeZone:zone).key,"2026-W53")
        for t in QuestCatalog.templates where t.family == .frequency || t.family == .consistency {
            XCTAssertLessThanOrEqual(QuestRules.target(for:t,cadence:.daily,activity:.init(readingDaysPerWeek:[999])),1)
            XCTAssertLessThanOrEqual(QuestRules.target(for:t,cadence:.weekly,activity:.init(readingDaysPerWeek:[999])),7)
            XCTAssertEqual(QuestRules.target(for:t,cadence:.daily,activity:.init(sessionsPerWeek:[999])),1,"Sessions must not be interpreted as recorded days")
        }
    }
}
