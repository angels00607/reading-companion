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
    public func awardXP(_ award:XPAward) throws -> Bool { try queue.write { db in let inserted = try insertXPAward(award,db:db); try evaluateAchievements(db); return inserted } }
    public func quests() throws -> [QuestInstance] { try queue.read { db in try Row.fetchAll(db,sql:"SELECT * FROM quest_instances WHERE owner_id=? ORDER BY cadence,period_key,id",arguments:[ownerID.uuidString]).map { row in
        QuestInstance(id:UUID(uuidString:row["id"])!,templateKey:row["template_key"],cadence:QuestCadence(rawValue:row["cadence"])!,periodKey:row["period_key"],title:row["title"],unit:row["unit"],target:row["target"],progress:row["progress"],completedAt:(row["completed_at"] as String?).flatMap(ISO8601DateFormatter().date),rerolledAt:(row["rerolled_at"] as String?).flatMap(ISO8601DateFormatter().date)) }
    } }
    public func saveQuests(_ values:[QuestInstance]) throws { try queue.write { db in for q in values { try saveQuest(q,db:db) } } }
    public func achievementProgress() throws -> [AchievementProgress] { try queue.read { db in
        let rows=try Row.fetchAll(db,sql:"SELECT * FROM achievement_progress WHERE owner_id=?",arguments:[ownerID.uuidString]); let map=Dictionary(uniqueKeysWithValues:rows.map{($0["achievement_key"] as String,$0)})
        return AchievementCatalog.all.map { definition in let row=map[definition.key]; return AchievementProgress(definition:definition,progress:row?["progress"] ?? 0,unlockedAt:(row?["unlocked_at"] as String?).flatMap(ISO8601DateFormatter().date)) }
    } }
    public func saveAchievementProgress(_ values:[AchievementProgress]) throws { try queue.write { db in for a in values {
        guard a.progressKnown, AchievementCatalog.all.contains(a.definition) else { throw GamificationError.invalidTarget }
        try db.execute(sql:"""
        INSERT INTO achievement_progress(owner_id,achievement_key,progress,unlocked_at) VALUES(?,?,?,?) ON CONFLICT(owner_id,achievement_key) DO UPDATE SET progress=max(achievement_progress.progress,excluded.progress),unlocked_at=coalesce(achievement_progress.unlocked_at,excluded.unlocked_at)
        """,arguments:[ownerID.uuidString,a.definition.key,a.progress,a.unlockedAt.map(ISO8601DateFormatter().string)]); if a.isUnlocked, a.definition.xp > 0 { _ = try insertXPAward(try XPAward(semanticKey:"achievement:\(a.definition.key)",source:.achievement,amount:a.definition.xp),db:db) } } } }
    public func cosmeticStates() throws -> [String:CosmeticState] { try queue.read { db in
        let level = GamificationBalance.level(totalXP:try Int.fetchOne(db,sql:"SELECT COALESCE(SUM(amount),0) FROM xp_awards WHERE owner_id=?",arguments:[ownerID.uuidString]) ?? 0)
        let saved = Dictionary(uniqueKeysWithValues:try Row.fetchAll(db,sql:"SELECT cosmetic_key,state FROM user_cosmetics WHERE owner_id=?",arguments:[ownerID.uuidString]).map { ($0["cosmetic_key"] as String,$0["state"] as String) })
        return Dictionary(uniqueKeysWithValues:CosmeticCatalog.all.map { item in
            (item.key,level < item.unlockLevel ? .locked : saved[item.key] == "equipped" ? .equipped : .unlocked)
        })
    } }
    public func setCosmetic(_ key:String,state:CosmeticState) throws { try queue.write { db in
        let level = GamificationBalance.level(totalXP:try Int.fetchOne(db,sql:"SELECT COALESCE(SUM(amount),0) FROM xp_awards WHERE owner_id=?",arguments:[ownerID.uuidString]) ?? 0)
        guard state != .locked, let item = CosmeticCatalog.all.first(where:{$0.key==key}), level >= item.unlockLevel else { throw GamificationError.lockedCosmetic }
        func equip(_ definition: CosmeticDefinition, _ choice: CosmeticState) throws {
            if choice == .equipped { for other in CosmeticCatalog.all where other.category == definition.category && other.key != definition.key {
                try db.execute(sql:"UPDATE user_cosmetics SET state='unlocked',updated_at=? WHERE owner_id=? AND cosmetic_key=? AND state='equipped'",arguments:[stamp(gamificationNow()),ownerID.uuidString,other.key])
            } }
            try db.execute(sql:"INSERT INTO user_cosmetics(owner_id,cosmetic_key,state,updated_at) VALUES(?,?,?,?) ON CONFLICT(owner_id,cosmetic_key) DO UPDATE SET state=excluded.state,updated_at=excluded.updated_at",arguments:[ownerID.uuidString,definition.key,choice.rawValue,stamp(gamificationNow())])
        }
        try equip(item,state)
        // The V1 theme is a preset of existing, Level-1 decorative surfaces only.
        if item.category == .themes && state == .equipped {
            for preset in CosmeticCatalog.all where ["background.midnight","frame.classic"].contains(preset.key) {
                guard level >= preset.unlockLevel else { throw GamificationError.lockedCosmetic }; try equip(preset,.equipped)
            }
        }
    } }
    private func encode<T:Encodable>(_ value:T) throws -> String { String(data:try JSONEncoder().encode(value),encoding:.utf8)! }
    private func decode<T:Decodable>(_ value:String) throws -> T { try JSONDecoder().decode(T.self,from:Data(value.utf8)) }
}
