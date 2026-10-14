import Foundation

/// Lossless, versioned payloads for the first two SQLite entities.
/// Values deliberately preserve the local column names and nullable fields.
/// Local revision and cloud revision are separate counters.
public enum CoreSyncPayloads {
    public static let schemaVersion = 1

    public struct Book: Codable, Equatable, Sendable {
        public let schemaVersion: Int
        public let title: String
        public let author: String
        public let localRevision: Int64
        public let deletedAt: String?

        public init(title: String, author: String, localRevision: Int64, deletedAt: String?) throws {
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  localRevision >= 0 else { throw PayloadError.invalidLocalRow }
            self.schemaVersion = CoreSyncPayloads.schemaVersion
            self.title = title
            self.author = author
            self.localRevision = localRevision
            self.deletedAt = deletedAt
        }
    }

    public struct Reading: Codable, Equatable, Sendable {
        public let schemaVersion: Int
        public let bookID: UUID
        public let editionID: UUID?
        public let status: Status
        public let currentPage: Int
        public let totalPages: Int?
        public let startDate: String?
        public let finishDate: String?
        public let ratingState: RatingState
        public let ratingWhole: Int?
        public let journalFormat: JournalFormat?
        public let historical: Bool
        public let localRevision: Int64
        public let deletedAt: String?

        public init(bookID: UUID, editionID: UUID?, status: Status, currentPage: Int,
                    totalPages: Int?, startDate: String?, finishDate: String?,
                    ratingState: RatingState, ratingWhole: Int?, journalFormat: JournalFormat?,
                    historical: Bool, localRevision: Int64, deletedAt: String?) throws {
            guard currentPage >= 0, totalPages.map({ $0 > 0 && currentPage <= $0 }) ?? true,
                  localRevision >= 0,
                  (ratingState == .rated && (ratingWhole.map { (1...5).contains($0) } ?? false))
                    || (ratingState != .rated && ratingWhole == nil) else {
                throw PayloadError.invalidLocalRow
            }
            self.schemaVersion = CoreSyncPayloads.schemaVersion
            self.bookID = bookID
            self.editionID = editionID
            self.status = status
            self.currentPage = currentPage
            self.totalPages = totalPages
            self.startDate = startDate
            self.finishDate = finishDate
            self.ratingState = ratingState
            self.ratingWhole = ratingWhole
            self.journalFormat = journalFormat
            self.historical = historical
            self.localRevision = localRevision
            self.deletedAt = deletedAt
        }
    }

    public enum Status: String, Codable, Sendable { case currently_reading, read, dnf }
    public enum RatingState: String, Codable, Sendable { case unknown, unrated, rated }
    public enum JournalFormat: String, Codable, Sendable { case paperback, hardcover, ebook, audiobook }
    public enum PayloadError: Error { case invalidLocalRow }
}
