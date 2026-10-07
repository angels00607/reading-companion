import Foundation
import GRDB
import ReadingDomain

extension LocalStore {
    /// Target adaptation reads genuine pre-Phase-7 facts too. It never turns
    /// these rows into new events, synthetic sessions, progress or ordinary XP.
    func adaptiveQuestActivity(_ db: Database) throws -> ActivitySummary {
        let now = gamificationNow(), today = QuestPeriod(cadence:.daily,now:now,timeZone:gamificationTimeZone).key
        var pages = [String:Int](), journal = [String:Int](), days = Set<String>(), completions = [String:Int]()
        func localDay(_ timestamp:String) -> String? {
            guard let date = ISO8601DateFormatter().date(from:timestamp), date <= now else { return nil }
            return QuestPeriod(cadence:.daily,now:date,timeZone:gamificationTimeZone).key
        }
        for row in try Row.fetchAll(db,sql:"SELECT family,activity_date,SUM(quantity) AS amount FROM gamification_activity WHERE owner_id=? AND occurred_at<=? GROUP BY family,activity_date",arguments:[ownerID.uuidString,stamp(now)]) {
            let date: String = row["activity_date"], family: String = row["family"], amount: Int = row["amount"]
            switch family {
            case "pages": pages[date,default:0] += amount
            case "journalActivity": journal[date,default:0] += amount
            case "frequency": days.insert(date)
            case "completion": completions[String(date.prefix(7)),default:0] += amount
            default: break
            }
        }
        // Positive, resolved Page observations only; never percentages or invented dates.
        for row in try Row.fetchAll(db,sql:"""
            SELECT o.recorded_at,o.new_page-o.previous_page AS amount FROM progress_observations o
            JOIN readings r ON r.owner_id=o.owner_id AND r.id=o.reading_id
            WHERE o.owner_id=? AND r.historical=0 AND o.mode='page' AND o.requires_review=0
              AND o.new_page>o.previous_page AND o.recorded_at<=?
              AND NOT EXISTS(SELECT 1 FROM gamification_activity g WHERE g.owner_id=o.owner_id AND lower(g.semantic_key)=lower('pages:'||o.id))
            """,arguments:[ownerID.uuidString,stamp(now)]) {
            if let day = localDay(row["recorded_at"]) { pages[day,default:0] += row["amount"] as Int }
        }
        for date in try String.fetchAll(db,sql:"""
            SELECT DISTINCT a.activity_date FROM reading_activity_dates a JOIN readings r ON r.owner_id=a.owner_id AND r.id=a.reading_id
            WHERE a.owner_id=? AND a.source='user' AND r.historical=0 AND a.activity_date<=?
            """,arguments:[ownerID.uuidString,today]) { days.insert(date) }
        for date in try String.fetchAll(db,sql:"""
            SELECT r.finish_date FROM readings r WHERE r.owner_id=? AND r.historical=0 AND r.status='read'
              AND r.finish_date IS NOT NULL AND r.finish_date<=?
              AND NOT EXISTS(SELECT 1 FROM gamification_activity g WHERE g.owner_id=r.owner_id AND g.family='completion' AND lower(g.entity_id)=lower(r.id))
            """,arguments:[ownerID.uuidString,today]) { completions[String(date.prefix(7)),default:0] += 1 }
        for timestamp in try String.fetchAll(db,sql:"""
            SELECT c.copied_at FROM journal_components c JOIN readings r ON r.owner_id=c.owner_id AND r.id=c.reading_id
            WHERE c.owner_id=? AND c.component='book_review' AND c.state='copied' AND r.historical=0
              AND c.copied_at IS NOT NULL AND c.copied_at<=?
              AND NOT EXISTS(SELECT 1 FROM gamification_activity g WHERE g.owner_id=c.owner_id AND g.family='journalActivity' AND lower(g.entity_id)=lower(c.reading_id))
            """,arguments:[ownerID.uuidString,stamp(now)]) {
            if let day = localDay(timestamp) { journal[day,default:0] += 1 }
        }
        var journalWeeks = [String:Int](), dayWeeks = [String:Int]()
        for date in days {
            if let start = QuestPeriod.start(cadence:.daily,key:date,timeZone:gamificationTimeZone) {
                dayWeeks[QuestPeriod(cadence:.weekly,now:start,timeZone:gamificationTimeZone).key,default:0] += 1
            }
        }
        for (date,amount) in journal {
            if let start = QuestPeriod.start(cadence:.daily,key:date,timeZone:gamificationTimeZone) {
                journalWeeks[QuestPeriod(cadence:.weekly,now:start,timeZone:gamificationTimeZone).key,default:0] += amount
            }
        }
        return ActivitySummary(genuinePagesPerDay:pages.keys.sorted().map { pages[$0]! },completionsPerMonth:completions.keys.sorted().map { completions[$0]! },journalActionsPerWeek:journalWeeks.keys.sorted().map { journalWeeks[$0]! },readingDaysPerWeek:dayWeeks.keys.sorted().map { dayWeeks[$0]! })
    }
    func recordedGenuineDay(_ date: String, db: Database) throws -> Bool {
        (try Int.fetchOne(db,sql:"""
            SELECT COUNT(*) FROM reading_activity_dates a JOIN readings r ON r.owner_id=a.owner_id AND r.id=a.reading_id
            WHERE a.owner_id=? AND a.activity_date=? AND a.source='user' AND r.historical=0
            """,arguments:[ownerID.uuidString,date]) ?? 0) > 0
    }
}
