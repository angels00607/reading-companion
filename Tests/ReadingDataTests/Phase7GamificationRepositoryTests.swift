import XCTest
import ReadingDomain
@testable import ReadingData

final class Phase7GamificationRepositoryTests:XCTestCase {
    private func store() throws -> LocalStore { try .init(path:":memory:",ownerID:UUID()) }
    func testPermanentIdempotentLedger() throws { let s=try store(),a=try XPAward(semanticKey:"finish:reading-1",source:.finishBook,amount:100); XCTAssertTrue(try s.awardXP(a)); XCTAssertFalse(try s.awardXP(try XPAward(semanticKey:a.semanticKey,source:.finishBook,amount:100))); XCTAssertEqual(try s.xpAwards().map(\.amount),[100]) }
    func testPassportRequiresExactlyThreeUniqueFeaturedAchievementsWhenConfigured() throws { let s=try store(); XCTAssertThrowsError(try s.savePassport(.init(name:"Reader",featuredAchievementKeys:["books.first"]))); let keys=Array(AchievementCatalog.all.prefix(3).map(\.key)); try s.savePassport(.init(name:"Sarah",readingSince:2020,featuredAchievementKeys:keys)); XCTAssertEqual(try s.passport().featuredAchievementKeys,keys) }
    func testQuestCompletionPersistsAndAwardsOnce() throws { let s=try store(); var q=QuestRules.candidates(cadence:.daily,periodKey:"2026-10-06",activity:.init(),history:[]); q[0].progress=q[0].target; q[0].completedAt=Date(); try s.saveQuests(q); XCTAssertEqual(try s.quests().count,2); XCTAssertEqual(try s.quests().filter(\.isComplete).count,1); XCTAssertEqual(try s.xpAwards().map(\.amount),[20]); try s.saveQuests(q); XCTAssertEqual(try s.xpAwards().count,1) }
    func testAchievementsAreAllVisibleAndUnlockIsMonotonic() throws { let s=try store(); var values=try s.achievementProgress(); XCTAssertEqual(values.count,AchievementCatalog.all.count); values[0] = .init(definition:values[0].definition,progress:1,unlockedAt:Date()); try s.saveAchievementProgress(values); let unlocked=try s.achievementProgress().first!; XCTAssertTrue(unlocked.isUnlocked); try s.saveAchievementProgress([.init(definition:unlocked.definition,progress:0,unlockedAt:nil)]); XCTAssertTrue(try s.achievementProgress().first!.isUnlocked); XCTAssertEqual(try s.achievementProgress().first!.progress,1) }
    func testCosmeticsCannotPersistLockedAndRemainOwnerScoped() throws { let s=try store(),key=CosmeticCatalog.all[0].key; XCTAssertThrowsError(try s.setCosmetic(key,state:.locked)); try s.setCosmetic(key,state:.equipped); XCTAssertEqual(try s.cosmeticStates()[key],.equipped) }
}
