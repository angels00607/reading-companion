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
    // An exact date and an announced/published state do not establish source verification.
    // The current Series schema has no per-entry release-date provenance or verified flag.
    // Do not schedule alerts from unverified user-entered dates. Keep the delivery
    // infrastructure available until a separately specified verification flow exists.
    public func verifiedNotificationEvents(after date:ReadingDate) throws -> [VerifiedNotificationEvent] {
        []
    }
    private func ensureNotificationPreferences(_ db:Database) throws { try db.execute(sql:"INSERT OR IGNORE INTO notification_preferences(owner_id,updated_at) VALUES(?,?)",arguments:[ownerID.uuidString,stamp()]) }
}
