import Foundation
import GRDB
import ReadingDomain

/// Read-only export of SQLite rows. Never changes the local owner or database.
public enum CoreSyncSQLiteExport {
    public struct Snapshot: Sendable {
        public let books: [UUID: CoreSyncPayloads.Book]
        public let readings: [UUID: CoreSyncPayloads.Reading]
    }

    public enum ExportError: Error {
        case invalidIdentifier(table: String, value: String)
        case invalidEnum(table: String, value: String)
        case invalidBoolean(table: String)
    }

    public static func snapshot(from db: Database, ownerID: String) throws -> Snapshot {
        let bookRows = try Row.fetchAll(db, sql: """
            SELECT id, title, author, revision, deleted_at
            FROM books WHERE owner_id = ? ORDER BY id
            """, arguments: [ownerID])
        var books: [UUID: CoreSyncPayloads.Book] = [:]
        for row in bookRows {
            let rawID: String = row["id"]
            guard let id = UUID(uuidString: rawID) else {
                throw ExportError.invalidIdentifier(table: "books", value: rawID)
            }
            books[id] = try CoreSyncPayloads.Book(
                title: row["title"], author: row["author"],
                localRevision: row["revision"], deletedAt: row["deleted_at"])
        }

        let readingRows = try Row.fetchAll(db, sql: """
            SELECT id, book_id, edition_id, status, current_page, total_pages,
                   start_date, finish_date, rating_state, rating_whole,
                   journal_format, historical, revision, deleted_at
            FROM readings WHERE owner_id = ? ORDER BY id
            """, arguments: [ownerID])
        var readings: [UUID: CoreSyncPayloads.Reading] = [:]
        for row in readingRows {
            let rawID: String = row["id"]
            let rawBookID: String = row["book_id"]
            guard let id = UUID(uuidString: rawID),
                  let bookID = UUID(uuidString: rawBookID) else {
                throw ExportError.invalidIdentifier(table: "readings", value: rawID)
            }
            let rawEditionID: String? = row["edition_id"]
            let editionID: UUID?
            if let rawEditionID {
                guard let parsed = UUID(uuidString: rawEditionID) else {
                    throw ExportError.invalidIdentifier(table: "editions", value: rawEditionID)
                }
                editionID = parsed
            } else {
                editionID = nil
            }
            let rawStatus: String = row["status"]
            let rawRatingState: String = row["rating_state"]
            guard let status = CoreSyncPayloads.Status(rawValue: rawStatus),
                  let ratingState = CoreSyncPayloads.RatingState(rawValue: rawRatingState) else {
                throw ExportError.invalidEnum(table: "readings", value: rawStatus)
            }
            let rawFormat: String? = row["journal_format"]
            let journalFormat: CoreSyncPayloads.JournalFormat?
            if let rawFormat {
                guard let parsed = CoreSyncPayloads.JournalFormat(rawValue: rawFormat) else {
                    throw ExportError.invalidEnum(table: "readings", value: rawFormat)
                }
                journalFormat = parsed
            } else {
                journalFormat = nil
            }
            let historicalInt: Int = row["historical"]
            guard historicalInt == 0 || historicalInt == 1 else {
                throw ExportError.invalidBoolean(table: "readings")
            }
            readings[id] = try CoreSyncPayloads.Reading(
                bookID: bookID, editionID: editionID, status: status,
                currentPage: row["current_page"], totalPages: row["total_pages"],
                startDate: row["start_date"], finishDate: row["finish_date"],
                ratingState: ratingState, ratingWhole: row["rating_whole"],
                journalFormat: journalFormat, historical: historicalInt == 1,
                localRevision: row["revision"], deletedAt: row["deleted_at"])
        }
        return Snapshot(books: books, readings: readings)
    }
}
