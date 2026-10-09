import Foundation
import GRDB
import ReadingDomain

extension LocalStore: OnboardingRepository {
    public func onboardingState() throws -> OnboardingState {
        try queue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM onboarding_state WHERE owner_id=?", arguments: [ownerID.uuidString]) else {
                return OnboardingState()
            }
            let step = OnboardingStep(rawValue: row["step"]) ?? .welcome
            let language = (row["preferred_edition_language"] as String?).flatMap(PreferredEditionLanguage.init(rawValue:))
            let choice = (row["library_choice"] as String?).flatMap(OnboardingLibraryChoice.init(rawValue:))
            let completedAt = (row["completed_at"] as String?).flatMap(ISO8601DateFormatter().date(from:))
            return OnboardingState(step: step, readingHistorySince: row["reading_history_since"], preferredEditionLanguage: language, libraryChoice: choice, completedAt: completedAt)
        }
    }

    public func saveOnboardingState(_ state: OnboardingState) throws {
        try validateOnboarding(state, completing: false)
        try queue.write { db in try writeOnboarding(state, db: db) }
    }

    public func hasCompletedStoryGraphImport() throws -> Bool {
        try queue.read { db in
            (try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM import_runs WHERE owner_id=?", arguments: [ownerID.uuidString]) ?? 0) > 0
        }
    }

    public func completeOnboarding(_ state: OnboardingState) throws -> OnboardingState {
        try validateOnboarding(state, completing: true)
        if state.libraryChoice == .storyGraphImport, try !hasCompletedStoryGraphImport() { throw OnboardingError.importNotCompleted }
        var completed = state
        completed.step = .completed
        let completionStamp = stamp()
        completed.completedAt = ISO8601DateFormatter().date(from: completionStamp)
        try queue.write { db in
            let existing = try Row.fetchOne(db, sql: "SELECT * FROM reader_profiles WHERE owner_id=?", arguments: [ownerID.uuidString])
            let name: String = existing?["display_name"] ?? "Reader"
            let avatar: String = existing?["avatar_symbol"] ?? "person.crop.circle.fill"
            let favorites: String = existing?["favorite_books_json"] ?? "[]"
            let featured: String = existing?["featured_achievement_keys_json"] ?? "[]"
            try db.execute(sql: """
                INSERT INTO reader_profiles(owner_id,display_name,avatar_symbol,reading_since,favorite_books_json,favorite_series,favorite_author,favorite_genre,featured_achievement_keys_json,updated_at)
                VALUES(?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(owner_id) DO UPDATE SET reading_since=excluded.reading_since,updated_at=excluded.updated_at
                """, arguments: [ownerID.uuidString, name, avatar, completed.readingHistorySince!, favorites,
                    existing?["favorite_series"] as String?, existing?["favorite_author"] as String?, existing?["favorite_genre"] as String?, featured, completionStamp])
            try writeOnboarding(completed, db: db)
        }
        return completed
    }

    private func validateOnboarding(_ state: OnboardingState, completing: Bool) throws {
        if let year = state.readingHistorySince {
            let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
            guard (1000...currentYear).contains(year) else { throw OnboardingError.invalidReadingHistoryYear }
        }
        if completing {
            guard state.readingHistorySince != nil, state.preferredEditionLanguage != nil, state.libraryChoice != nil else { throw OnboardingError.incompleteStep }
        }
    }

    private func writeOnboarding(_ state: OnboardingState, db: Database) throws {
        try db.execute(sql: """
            INSERT INTO onboarding_state(owner_id,step,reading_history_since,preferred_edition_language,library_choice,completed_at,updated_at)
            VALUES(?,?,?,?,?,?,?)
            ON CONFLICT(owner_id) DO UPDATE SET step=excluded.step,reading_history_since=excluded.reading_history_since,
              preferred_edition_language=excluded.preferred_edition_language,library_choice=excluded.library_choice,
              completed_at=excluded.completed_at,updated_at=excluded.updated_at
            """, arguments: [ownerID.uuidString, state.step.rawValue, state.readingHistorySince,
                state.preferredEditionLanguage?.rawValue, state.libraryChoice?.rawValue,
                state.completedAt.map(ISO8601DateFormatter().string(from:)), stamp()])
    }
}
