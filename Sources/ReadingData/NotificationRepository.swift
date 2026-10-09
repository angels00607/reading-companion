import Foundation
import GRDB
import ReadingDomain

extension LocalStore:NotificationPreferencesRepository {
    public func notificationPreferences() throws -> NotificationPreferences { try queue.write { db in
        try ensureNotificationPreferences(db)
        let row=try Row.fetchOne(db,sql:"SELECT * FROM notification_preferences WHERE owner_id=?",arguments:[ownerID.uuidString])!
        let achievements:Int?=row["achievements_levels"]
        return .init(seriesReleases:row["series_releases"],releaseDateChanges:row["release_date_changes"],importAndSystem:row["import_system"],challenges:row["challenges"],journal:row["journal"],quests:row["quests"],achievementsAndLevels:achievements.map{$0 != 0})
    } }
    public func setNotificationPreference(_ category:NotificationCategory,enabled:Bool) throws { try queue.write { db in
        try ensureNotificationPreferences(db)
        let column:String=switch category { case .seriesReleases:"series_releases";case .releaseDateChanges:"release_date_changes";case .importAndSystem:"import_system";case .challenges:"challenges";case .journal:"journal";case .quests:"quests";case .achievementsAndLevels:"achievements_levels" }
        try db.execute(sql:"UPDATE notification_preferences SET \(column)=?,updated_at=? WHERE owner_id=?",arguments:[enabled,stamp(),ownerID.uuidString])
    } }
    public func verifiedNotificationEvents(after date:ReadingDate) throws -> [VerifiedNotificationEvent] { try queue.read { db in
        try Row.fetchAll(db,sql:"""
            SELECT e.id,e.series_id,e.release_value FROM series_entries e
            JOIN series s ON s.owner_id=e.owner_id AND s.id=e.series_id
            WHERE e.owner_id=? AND e.included=1 AND e.release_precision='exact'
              AND e.publication IN ('published','announced') AND e.release_value>?
            ORDER BY e.release_value,e.id
            """,arguments:[ownerID.uuidString,date.isoString]).compactMap { row in
                guard let entry=UUID(uuidString:row["id"]),let series=UUID(uuidString:row["series_id"]),let release=try? JSONDecoder().decode(ReadingDate.self,from:JSONEncoder().encode(row["release_value"] as String)) else{return nil}
                return VerifiedNotificationEvent(id:"readingcompanion.series_releases.\(ownerID.uuidString).\(entry.uuidString)",category:.seriesReleases,date:release,destination:.series(series),title:"A series release is coming",body:"Open Reading Companion to view the verified release information.")
            }
    } }
    private func ensureNotificationPreferences(_ db:Database) throws { try db.execute(sql:"INSERT OR IGNORE INTO notification_preferences(owner_id,updated_at) VALUES(?,?)",arguments:[ownerID.uuidString,stamp()]) }
}
