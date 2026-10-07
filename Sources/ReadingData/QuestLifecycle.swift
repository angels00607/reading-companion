import Foundation
import GRDB
import ReadingDomain

extension LocalStore {
    func questHistory(_ db: Database) throws -> [QuestInstance] {
        try Row.fetchAll(db,sql:"SELECT * FROM quest_instances WHERE owner_id=? ORDER BY cadence,period_key,id",arguments:[ownerID.uuidString]).map { row in
            QuestInstance(id:UUID(uuidString:row["id"])!,templateKey:row["template_key"],cadence:QuestCadence(rawValue:row["cadence"])!,periodKey:row["period_key"],title:row["title"],unit:row["unit"],target:row["target"],progress:row["progress"],completedAt:(row["completed_at"] as String?).flatMap(ISO8601DateFormatter().date),rerolledAt:(row["rerolled_at"] as String?).flatMap(ISO8601DateFormatter().date))
        }
    }
    func saveQuest(_ q: QuestInstance, db: Database) throws {
        guard q.target > 0, q.progress <= q.target else { throw GamificationError.invalidTarget }
        try db.execute(sql:"""
            INSERT INTO quest_instances(owner_id,id,template_key,cadence,period_key,title,unit,target,progress,completed_at,rerolled_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(owner_id,id) DO UPDATE SET progress=max(quest_instances.progress,excluded.progress),completed_at=coalesce(quest_instances.completed_at,excluded.completed_at),rerolled_at=coalesce(quest_instances.rerolled_at,excluded.rerolled_at)
            """,arguments:[ownerID.uuidString,q.id.uuidString,q.templateKey,q.cadence.rawValue,q.periodKey,q.title,q.unit,q.target,q.progress,q.completedAt.map(stamp),q.rerolledAt.map(stamp)])
        if q.isComplete { _ = try insertXPAward(try XPAward(semanticKey:"quest:\(q.id.uuidString)",source:q.cadence.xpSource,amount:q.cadence.xp,awardedAt:gamificationNow()),db:db) }
    }
    private func period(_ cadence: QuestCadence) -> QuestPeriod { .init(cadence:cadence,now:gamificationNow(),timeZone:gamificationTimeZone) }
    private func activityCount(_ family: QuestFamily, period: QuestPeriod, db: Database) throws -> Int {
        let source = family == .consistency ? QuestFamily.frequency : family
        let aggregate = source == .frequency ? "COUNT(DISTINCT activity_date)" : source == .organization ? "COUNT(DISTINCT entity_id)" : "COALESCE(SUM(quantity),0)"
        return try Int.fetchOne(db,sql:"SELECT \(aggregate) FROM gamification_activity WHERE owner_id=? AND family=? AND occurred_at>=? AND occurred_at<?",arguments:[ownerID.uuidString,source.rawValue,stamp(period.start),stamp(period.end)]) ?? 0
    }
    private func eligibleTemplates(_ p: QuestPeriod, history: [QuestInstance], db: Database) throws -> [QuestTemplate] {
        let actual = try Row.fetchAll(db,sql:"SELECT family,quantity FROM gamification_activity WHERE owner_id=? ORDER BY occurred_at",arguments:[ownerID.uuidString])
        let known = Set(actual.map { $0["family"] as String })
        let active = try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM readings WHERE owner_id=? AND status='currently_reading' AND historical=0 AND deleted_at IS NULL",arguments:[ownerID.uuidString]) ?? 0
        let journal = try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM journal_components c JOIN readings r ON r.owner_id=c.owner_id AND r.id=c.reading_id WHERE c.owner_id=? AND c.component='book_review' AND c.state='ready' AND r.historical=0",arguments:[ownerID.uuidString]) ?? 0
        let todayCounted = try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM gamification_activity WHERE owner_id=? AND family='frequency' AND activity_date=?",arguments:[ownerID.uuidString,period(.daily).key]) ?? 0
        let eligible = QuestCatalog.templates.filter { t in
            guard t.cadences.contains(p.cadence), QuestPeriod.cooldownAllows(t,cadence:p.cadence,periodKey:p.key,history:history,timeZone:gamificationTimeZone) else { return false }
            switch t.family {
            case .progress,.organization: return true // Explicit small actions; no inferred reading activity.
            case .sessions: return false // No authoritative session recorder exists in V1.
            case .completion: return active > 0
            case .journalActivity: return journal > 0
            case .pages: return known.contains(t.family.rawValue) && active > 0
            case .frequency,.consistency:
                return known.contains(QuestFamily.frequency.rawValue) && p.availableDays > (todayCounted > 0 ? 1 : 0)
            }
        }
        // Prefer evidenced activity families, then small baseline actions. Vary families
        // within a set when feasible, while retaining distinct safe templates for clean starts.
        let preferred = eligible.filter { ![QuestFamily.progress,.organization].contains($0.family) } + eligible.filter { [.progress,.organization].contains($0.family) }
        var ordered = [QuestTemplate](), families = Set<QuestFamily>()
        for t in preferred where !families.contains(t.family) { ordered.append(t); families.insert(t.family) }
        ordered += preferred.filter { t in !ordered.contains(where: { $0.key == t.key }) }
        return ordered
    }
    private func makeQuest(_ t: QuestTemplate, period p: QuestPeriod, db: Database) throws -> QuestInstance {
        let rows = try Row.fetchAll(db,sql:"SELECT family,activity_date,SUM(quantity) AS amount FROM gamification_activity WHERE owner_id=? GROUP BY family,activity_date ORDER BY activity_date",arguments:[ownerID.uuidString])
        let pages = rows.filter { ($0["family"] as String) == "pages" }.map { $0["amount"] as Int }
        var journal = [String:Int](), days = [String:Int](), completions = [String:Int]()
        for row in rows {
            let date: String = row["activity_date"], family: String = row["family"], amount: Int = row["amount"]
            if family == "completion" { completions[String(date.prefix(7)),default:0] += amount }
            guard let start = QuestPeriod.start(cadence:.daily,key:date,timeZone:gamificationTimeZone) else { continue }
            let week = QuestPeriod(cadence:.weekly,now:start,timeZone:gamificationTimeZone).key
            if family == "journalActivity" { journal[week,default:0] += amount }
            if family == "frequency" { days[week,default:0] += 1 }
        }
        let activity = ActivitySummary(genuinePagesPerDay:pages,completionsPerMonth:completions.keys.sorted().map { completions[$0]! },journalActionsPerWeek:journal.keys.sorted().map { journal[$0]! },readingDaysPerWeek:days.keys.sorted().map { days[$0]! })
        var target = QuestRules.target(for:t,cadence:p.cadence,activity:activity)
        if t.family == .frequency || t.family == .consistency {
            // A date already counted at creation cannot be counted again. Bound late starts.
            let todayCounted = try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM gamification_activity WHERE owner_id=? AND family='frequency' AND activity_date=?",arguments:[ownerID.uuidString,period(.daily).key]) ?? 0
            target = min(target,max(1,p.availableDays - (todayCounted > 0 ? 1 : 0)))
        }
        return .init(templateKey:t.key,cadence:p.cadence,periodKey:p.key,title:t.title,unit:t.unit,target:target)
    }
    private func register(_ q: QuestInstance, slot: Int, period: QuestPeriod, db: Database) throws {
        try saveQuest(q,db:db)
        let family = QuestCatalog.templates.first { $0.key == q.templateKey }?.family ?? .progress
        try db.execute(sql:"INSERT OR IGNORE INTO quest_lifecycle(owner_id,quest_id,slot,baseline,created_at) VALUES(?,?,?,?,?)",arguments:[ownerID.uuidString,q.id.uuidString,slot,try activityCount(family,period:period,db:db),stamp(gamificationNow())])
    }
    @discardableResult
    func ensureCurrentQuests(_ db: Database) throws -> [QuestInstance] {
        var history = try questHistory(db)
        for cadence in QuestCadence.allCases {
            let p = period(cadence)
            let current = history.filter { $0.cadence == cadence && $0.periodKey == p.key && $0.rerolledAt == nil }
            // Adopt existing state without deleting history or changing earned awards.
            for (slot,q) in current.prefix(cadence.activeCount).enumerated() { try register(q,slot:slot,period:p,db:db) }
            if current.count < cadence.activeCount {
                let candidates = try eligibleTemplates(p,history:history,db:db)
                for (offset,t) in candidates.prefix(cadence.activeCount-current.count).enumerated() {
                    let q = try makeQuest(t,period:p,db:db)
                    try register(q,slot:current.count+offset,period:p,db:db); history.append(q)
                }
            }
        }
        let persisted = try questHistory(db)
        var result = [QuestInstance]()
        for cadence in QuestCadence.allCases {
            let p = period(cadence)
            let ids = try String.fetchAll(db,sql:"SELECT q.id FROM quest_instances q JOIN quest_lifecycle l ON l.owner_id=q.owner_id AND l.quest_id=q.id WHERE q.owner_id=? AND q.cadence=? AND q.period_key=? AND q.rerolled_at IS NULL ORDER BY l.slot,l.created_at,q.id LIMIT ?",arguments:[ownerID.uuidString,cadence.rawValue,p.key,cadence.activeCount])
            for id in ids { if let q = persisted.first(where: { $0.id.uuidString == id }) { result.append(q) } }
        }
        return result
    }
    public func currentQuests() throws -> [QuestInstance] { try queue.write { db in
        let current = try ensureCurrentQuests(db); try evaluateAchievements(db); return current
    } }
    public func rerollAvailable(_ cadence: QuestCadence) throws -> Bool {
        guard cadence != .monthly else { return false }
        return try queue.write { db in
            let current = try ensureCurrentQuests(db), p = period(cadence), history = try questHistory(db)
            let candidates = try eligibleTemplates(p,history:history,db:db)
            return !history.contains { $0.cadence == cadence && $0.periodKey == p.key && $0.rerolledAt != nil } && current.contains { $0.cadence == cadence && !$0.isComplete } && !candidates.isEmpty
        }
    }
    public func rerollQuest(_ id: UUID) throws { try queue.write { db in
        let current = try ensureCurrentQuests(db), history = try questHistory(db)
        guard var old = current.first(where: { $0.id == id }), old.cadence != .monthly, !old.isComplete else { throw GamificationError.rerollUnavailable }
        let p = period(old.cadence)
        guard !history.contains(where: { $0.cadence == old.cadence && $0.periodKey == p.key && $0.rerolledAt != nil }),
              let t = try eligibleTemplates(p,history:history,db:db).first,
              let slot = try Int.fetchOne(db,sql:"SELECT slot FROM quest_lifecycle WHERE owner_id=? AND quest_id=?",arguments:[ownerID.uuidString,id.uuidString]) else { throw GamificationError.rerollUnavailable }
        let replacement = try makeQuest(t,period:p,db:db)
        old.rerolledAt = gamificationNow(); try saveQuest(old,db:db)
        try register(replacement,slot:slot,period:p,db:db)
    } }
    /// Called inside the real command's transaction. Replays and historical imports never advance live goals.
    func recordGamificationActivity(key: String, family: QuestFamily, entity: UUID, quantity: Int = 1, activityDate: String? = nil, db: Database) throws {
        guard quantity > 0 else { return }
        let now = gamificationNow(), today = period(.daily).key
        // Backdated reading-day facts remain available to Stats, not new live activity.
        guard activityDate == nil || activityDate == today else { return }
        let current = try ensureCurrentQuests(db)
        try db.execute(sql:"INSERT OR IGNORE INTO gamification_activity(owner_id,semantic_key,family,entity_id,quantity,activity_date,occurred_at) VALUES(?,?,?,?,?,?,?)",arguments:[ownerID.uuidString,key,family.rawValue,entity.uuidString,quantity,activityDate ?? today,stamp(now)])
        for var q in current where !q.isComplete {
            guard let t = QuestCatalog.templates.first(where: { $0.key == q.templateKey }) else { continue }
            let baseline = try Int.fetchOne(db,sql:"SELECT baseline FROM quest_lifecycle WHERE owner_id=? AND quest_id=?",arguments:[ownerID.uuidString,q.id.uuidString]) ?? 0
            q.progress = min(q.target,max(q.progress,try activityCount(t.family,period:period(q.cadence),db:db)-baseline))
            if q.progress >= q.target { q.completedAt = now }
            try saveQuest(q,db:db)
        }
        try evaluateAchievements(db)
    }
    func evaluateAchievements(_ db: Database) throws {
        // Persisted nonhistorical domain facts are authoritative even when they
        // predate the XP hook. Permanent award IDs preserve earned facts after deletion.
        // This evaluates catalog conditions; it does not backfill Finish/Journal XP.
        let books = try Int.fetchOne(db,sql:"""
            SELECT COUNT(*) FROM (
              SELECT lower(id) FROM readings WHERE owner_id=? AND historical=0 AND status='read' AND deleted_at IS NULL
              UNION SELECT lower(substr(x.semantic_key,13)) FROM xp_awards x JOIN xp_award_metadata m ON m.owner_id=x.owner_id AND m.semantic_key=x.semantic_key
              WHERE x.owner_id=? AND m.source='finishBook' AND x.semantic_key LIKE 'finish-book:%'
            )
            """,arguments:[ownerID.uuidString,ownerID.uuidString]) ?? 0
        let journal = try Int.fetchOne(db,sql:"""
            SELECT COUNT(*) FROM (
              SELECT lower(c.reading_id) FROM journal_components c JOIN readings r ON r.owner_id=c.owner_id AND r.id=c.reading_id
              WHERE c.owner_id=? AND c.component='book_review' AND c.state='copied' AND r.historical=0
              UNION SELECT lower(substr(x.semantic_key,14,36)) FROM xp_awards x JOIN xp_award_metadata m ON m.owner_id=x.owner_id AND m.semantic_key=x.semantic_key
              WHERE x.owner_id=? AND m.source='journalWork' AND x.semantic_key LIKE 'journal-work:%:book-review'
            )
            """,arguments:[ownerID.uuidString,ownerID.uuidString]) ?? 0
        let quests = try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM quest_instances WHERE owner_id=? AND completed_at IS NOT NULL",arguments:[ownerID.uuidString]) ?? 0
        for definition in AchievementCatalog.all {
            let total = try Int.fetchOne(db,sql:"SELECT COALESCE(SUM(amount),0) FROM xp_awards WHERE owner_id=?",arguments:[ownerID.uuidString]) ?? 0
            let progress: Int
            switch definition.key { case "books.first","books.ten": progress = books; case "journal.five": progress = journal; case "quests.ten": progress = quests; case "level.five": progress = GamificationBalance.level(totalXP:total); default: continue }
            let unlocked = progress >= definition.target ? stamp(gamificationNow()) : nil
            try db.execute(sql:"INSERT INTO achievement_progress(owner_id,achievement_key,progress,unlocked_at) VALUES(?,?,?,?) ON CONFLICT(owner_id,achievement_key) DO UPDATE SET progress=max(achievement_progress.progress,excluded.progress),unlocked_at=coalesce(achievement_progress.unlocked_at,excluded.unlocked_at)",arguments:[ownerID.uuidString,definition.key,progress,unlocked])
            if unlocked != nil, definition.xp > 0 { _ = try insertXPAward(try XPAward(semanticKey:"achievement:\(definition.key)",source:.achievement,amount:definition.xp,awardedAt:gamificationNow()),db:db) }
        }
    }
}
