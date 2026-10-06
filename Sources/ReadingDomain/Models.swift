import Foundation

public enum DomainError: Error, Equatable, Sendable {
    case invalidDate, invalidProgress, invalidTransition, confirmationRequired, invalidRating
    case unreliableEvidence, promptOccupied, staleRevision, externalFormatForbidden
}

/// Calendar date, deliberately not a UTC midnight masquerading as a reading day.
public struct ReadingDate: Codable, Equatable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public init(year: Int, month: Int, day: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = DateComponents(year: year, month: month, day: day)
        guard (1...9999).contains(year), let date = calendar.date(from: parts),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { throw DomainError.invalidDate }
        self.year = year; self.month = month; self.day = day
    }
    public var isoString: String { String(format: "%04d-%02d-%02d", year, month, day) }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.isoString < rhs.isoString }
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { throw DomainError.invalidDate }
        try self.init(year: parts[0], month: parts[1], day: parts[2])
        guard isoString == value else { throw DomainError.invalidDate }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer(); try container.encode(isoString)
    }
    public var isoWeek: ISOWeek {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        return ISOWeek(year: calendar.component(.yearForWeekOfYear, from: date),
                       week: calendar.component(.weekOfYear, from: date))
    }
}
public struct ISOWeek: Codable, Equatable, Sendable {
    public let year: Int
    public let week: Int
    public init(year: Int, week: Int) { self.year = year; self.week = week }
}
public struct Book: Codable, Equatable, Sendable {
    public let id: UUID
    public let ownerID: UUID
    public var title: String
    public var author: String
    public init(id: UUID = UUID(), ownerID: UUID, title: String, author: String) {
        self.id = id; self.ownerID = ownerID; self.title = title; self.author = author
    }
}
public struct Edition: Codable, Equatable, Sendable {
    public let id: UUID
    public let bookID: UUID
    public var language: String?
    public var pageCount: Int?
    public var title: String?
    public var isbn10: String?
    public var isbn13: String?
    public var coverReference: String?
    public var publisher: String?
    public init(id: UUID = UUID(), bookID: UUID, language: String? = nil, pageCount: Int? = nil,
                title: String? = nil, isbn10: String? = nil, isbn13: String? = nil,
                coverReference: String? = nil, publisher: String? = nil) {
        self.id = id; self.bookID = bookID; self.language = language; self.pageCount = pageCount
        self.title = title; self.isbn10 = isbn10; self.isbn13 = isbn13
        self.coverReference = coverReference; self.publisher = publisher
    }
}
public struct LibraryMembership: Codable, Equatable, Sendable {
    public let bookID: UUID
    public var wantsToRead: Bool
    public var removedAt: Date?
}
public enum ReadingStatus: String, Codable, Sendable { case currentlyReading = "currently_reading", read, dnf }
public enum JournalFormat: String, Codable, CaseIterable, Sendable { case paperback, hardcover, ebook, audiobook }
public enum Rating: Codable, Equatable, Sendable {
    case unknown, noRating, stars(Int)
    public static func validatedStars(_ value: Int) throws -> Self {
        guard (1...5).contains(value) else { throw DomainError.invalidRating }
        return .stars(value)
    }
}
public struct ReadingInstance: Codable, Equatable, Sendable {
    public let id: UUID
    public let bookID: UUID
    public var editionID: UUID?
    public var primaryGenre: String?
    public var status: ReadingStatus
    public internal(set) var progress: ReadingProgress
    public internal(set) var progressObservations: [ProgressObservation] = []
    public var startDate: ReadingDate?
    public var finishDate: ReadingDate?
    public var journalFormat: JournalFormat?
    public var rating: Rating
    public let historical: Bool
    public var revision: Int
    public init(id: UUID = UUID(), bookID: UUID, status: ReadingStatus = .currentlyReading,
                progress: ReadingProgress, historical: Bool = false) {
        self.id = id; self.bookID = bookID; self.status = status; self.progress = progress
        self.historical = historical; revision = 0
        editionID = nil; primaryGenre = nil
        rating = .unknown
    }
    /// Persistence hydration only: immutable observation values are never rewritten.
    public func restoringObservations(_ observations: [ProgressObservation]) -> Self {
        var copy = self; copy.progressObservations = observations; return copy
    }
}
public enum MutationOrigin: String, Codable, Sendable { case user, historicalImport, restore, provider }
public struct Provenance: Codable, Equatable, Sendable {
    public let origin: MutationOrigin
    public let sourceReference: String?
    public let evidenceFingerprint: String?
    public let userOverridden: Bool
    public init(origin: MutationOrigin, sourceReference: String?, evidenceFingerprint: String?, userOverridden: Bool) {
        self.origin = origin; self.sourceReference = sourceReference; self.evidenceFingerprint = evidenceFingerprint; self.userOverridden = userOverridden
    }
}
public struct ProposedChange<Value: Equatable & Sendable>: Equatable, Sendable {
    public let current: Value
    public let proposed: Value
    public let evidenceFingerprint: String
}
public enum MergeDecision: Equatable, Sendable { case apply, unchanged, review }
public enum OverridePolicy {
    public static func decide<Value: Equatable>(current: Value, incoming: Value,
        userOverridden: Bool, origin: MutationOrigin) -> MergeDecision {
        if current == incoming { return .unchanged }
        // All external changes require review, including fields without an override.
        if origin == .provider || origin == .historicalImport || userOverridden { return .review }
        return .apply
    }
    public static func mayPropose(fingerprint: String, rejected: Set<String>) -> Bool {
        !rejected.contains(fingerprint)
    }
}
