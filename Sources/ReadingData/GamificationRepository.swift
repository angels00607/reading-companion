import Foundation
import GRDB
import ReadingDomain

extension LocalStore: GamificationRepository {
    @discardableResult
    func insertXPAward(_ award: XPAward, db: Database) throws -> Bool {
        if try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM xp_awards WHERE owner_id=? AND semantic_key=?",arguments:[ownerID.uuidString,award.semanticKey])! > 0 { return false }
        try db.execute(sql:"INSERT INTO xp_awards(owner_id,semantic_key,amount,awarded_at) VALUES(?,?,?,?)",arguments:[ownerID.uuidString,award.semanticKey,award.amount,ISO8601DateFormatter().string(from:award.awardedAt)])
        try db.execute(sql:"INSERT INTO xp_award_metadata(owner_id,semantic_key,source) VALUES(?,?,?)",arguments:[ownerID.uuidString,award.semanticKey,award.source.rawValue])
        return true
    }
    public func passport() throws -> ReaderPassport {
        try queue.read { db in
            guard let row = try Row.fetchOne(db,sql:"SELECT * FROM reader_profiles WHERE owner_id=?",arguments:[ownerID.uuidString]) else { return ReaderPassport() }
            return ReaderPassport(name:row["display_name"],avatarSymbol:row["avatar_symbol"],readingSince:row["reading_since"],
                favoriteBooks:try decode(row["favorite_books_json"]),favoriteSeries:row["favorite_series"],favoriteAuthor:row["favorite_author"],favoriteGenre:row["favorite_genre"],featuredAchievementKeys:try decode(row["featured_achievement_keys_json"]))
        }
    }
    public func savePassport(_ value:ReaderPassport) throws {
        let featured=Array(Set(value.featuredAchievementKeys)); guard featured.count == value.featuredAchievementKeys.count, featured.count == 0 || featured.count == 3,
            featured.allSatisfy({ key in AchievementCatalog.all.contains{$0.key==key} }), (1000...9999).contains(value.readingSince), !value.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw GamificationError.invalidFeaturedSelection }
        try queue.write { db in try db.execute(sql:"""
            INSERT INTO reader_profiles(owner_id,display_name,avatar_symbol,reading_since,favorite_books_json,favorite_series,favorite_author,favorite_genre,featured_achievement_keys_json,updated_at)
            VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(owner_id) DO UPDATE SET display_name=excluded.display_name,avatar_symbol=excluded.avatar_symbol,reading_since=excluded.reading_since,favorite_books_json=excluded.favorite_books_json,favorite_series=excluded.favorite_series,favorite_author=excluded.favorite_author,favorite_genre=excluded.favorite_genre,featured_achievement_keys_json=excluded.featured_achievement_keys_json,updated_at=excluded.updated_at
            """,arguments:[ownerID.uuidString,value.name,value.avatarSymbol,value.readingSince,try encode(value.favoriteBooks),value.favoriteSeries,value.favoriteAuthor,value.favoriteGenre,try encode(value.featuredAchievementKeys),stamp()]) }
    }
    public func xpAwards() throws -> [XPAward] { try queue.read { db in try Row.fetchAll(db,sql:"SELECT x.*,m.source FROM xp_awards x LEFT JOIN xp_award_metadata m ON m.owner_id=x.owner_id AND m.semantic_key=x.semantic_key WHERE x.owner_id=? ORDER BY awarded_at,semantic_key",arguments:[ownerID.uuidString]).map { row in
        try XPAward(semanticKey:row["semantic_key"],source:XPSource(rawValue:(row["source"] as String?) ?? "achievement") ?? .achievement,amount:row["amount"],awardedAt:ISO8601DateFormatter().date(from:row["awarded_at"])!) }
    } }
    public func awardXP(_ award:XPAward) throws -> Bool { try queue.write { try insertXPAward(award,db:$0) } }
    public func quests() throws -> [QuestInstance] { try queue.read { db in try Row.fetchAll(db,sql:"SELECT * FROM quest_instances WHERE owner_id=? ORDER BY cadence,period_key,id",arguments:[ownerID.uuidString]).map { row in
        QuestInstance(id:UUID(uuidString:row["id"])!,templateKey:row["template_key"],cadence:QuestCadence(rawValue:row["cadence"])!,periodKey:row["period_key"],title:row["title"],unit:row["unit"],target:row["target"],progress:row["progress"],completedAt:(row["completed_at"] as String?).flatMap(ISO8601DateFormatter().date),rerolledAt:(row["rerolled_at"] as String?).flatMap(ISO8601DateFormatter().date)) }
    } }
    public func saveQuests(_ values:[QuestInstance]) throws { try queue.write { db in for q in values { guard q.target>0,q.progress<=q.target else { throw GamificationError.invalidTarget }; try db.execute(sql:"""
        INSERT INTO quest_instances(owner_id,id,template_key,cadence,period_key,title,unit,target,progress,completed_at,rerolled_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(owner_id,id) DO UPDATE SET progress=excluded.progress,completed_at=excluded.completed_at,rerolled_at=excluded.rerolled_at
        """,arguments:[ownerID.uuidString,q.id.uuidString,q.templateKey,q.cadence.rawValue,q.periodKey,q.title,q.unit,q.target,q.progress,q.completedAt.map(ISO8601DateFormatter().string),q.rerolledAt.map(ISO8601DateFormatter().string)]); if q.isComplete { _ = try insertXPAward(try XPAward(semanticKey:"quest:\(q.id.uuidString)",source:q.cadence.xpSource,amount:q.cadence.xp),db:db) } } } }
    public func achievementProgress() throws -> [AchievementProgress] { try queue.read { db in
        let rows=try Row.fetchAll(db,sql:"SELECT * FROM achievement_progress WHERE owner_id=?",arguments:[ownerID.uuidString]); let map=Dictionary(uniqueKeysWithValues:rows.map{($0["achievement_key"] as String,$0)})
        return AchievementCatalog.all.map { definition in let row=map[definition.key]; return AchievementProgress(definition:definition,progress:row?["progress"] ?? 0,unlockedAt:(row?["unlocked_at"] as String?).flatMap(ISO8601DateFormatter().date)) }
    } }
    public func saveAchievementProgress(_ values:[AchievementProgress]) throws { try queue.write { db in for a in values { try db.execute(sql:"""
        INSERT INTO achievement_progress(owner_id,achievement_key,progress,unlocked_at) VALUES(?,?,?,?) ON CONFLICT(owner_id,achievement_key) DO UPDATE SET progress=max(achievement_progress.progress,excluded.progress),unlocked_at=coalesce(achievement_progress.unlocked_at,excluded.unlocked_at)
        """,arguments:[ownerID.uuidString,a.definition.key,a.progress,a.unlockedAt.map(ISO8601DateFormatter().string)]); if a.isUnlocked, a.definition.xp > 0 { _ = try insertXPAward(try XPAward(semanticKey:"achievement:\(a.definition.key)",source:.achievement,amount:a.definition.xp),db:db) } } } }
    public func cosmeticStates() throws -> [String:CosmeticState] { try queue.read { db in Dictionary(uniqueKeysWithValues:try Row.fetchAll(db,sql:"SELECT cosmetic_key,state FROM user_cosmetics WHERE owner_id=?",arguments:[ownerID.uuidString]).map { ($0["cosmetic_key"] as String,CosmeticState(rawValue:$0["state"] as String)!) }) } }
    public func setCosmetic(_ key:String,state:CosmeticState) throws { guard state != .locked, CosmeticCatalog.all.contains(where:{$0.key==key}) else { throw GamificationError.lockedCosmetic }; try queue.write { db in try db.execute(sql:"INSERT INTO user_cosmetics(owner_id,cosmetic_key,state,updated_at) VALUES(?,?,?,?) ON CONFLICT(owner_id,cosmetic_key) DO UPDATE SET state=excluded.state,updated_at=excluded.updated_at",arguments:[ownerID.uuidString,key,state.rawValue,stamp()]) } }
    private func encode<T:Encodable>(_ value:T) throws -> String { String(data:try JSONEncoder().encode(value),encoding:.utf8)! }
    private func decode<T:Decodable>(_ value:String) throws -> T { try JSONDecoder().decode(T.self,from:Data(value.utf8)) }
}
