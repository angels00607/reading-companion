import Foundation

public enum JournalComponent: String, Codable, CaseIterable, Sendable {
    case bookReview = "book_review", series, challenges, favorite, quote
}
public enum JournalDecision: String, Codable, Sendable { case pending, selected, none }

public struct JournalEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let readingID: UUID
    public let bookID: UUID
    public var summary: String?
    public var pageCount: Int?
    public var components: [JournalComponent: JournalComponentStatus]
    public init(id: UUID, readingID: UUID, bookID: UUID, summary: String?, pageCount: Int?, components: [JournalComponent: JournalComponentStatus]) {
        self.id = id; self.readingID = readingID; self.bookID = bookID
        self.summary = summary; self.pageCount = pageCount; self.components = components
    }
    public var bookReviewState: JournalComponentStatus { components[.bookReview] ?? .pending }
}

public struct JournalInboxItem: Identifiable, Sendable {
    public var id: UUID { entry.id }
    public let entry: JournalEntry
    public let book: Book
    public let reading: ReadingInstance
    public init(entry: JournalEntry, book: Book, reading: ReadingInstance) {
        self.entry = entry; self.book = book; self.reading = reading
    }
}

public struct JournalQuote: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID; public let bookID: UUID; public let readingID: UUID?
    public var text: String; public var source: String?; public var includeInJournal: Bool; public var copiedAt: Date?
    public init(id: UUID = UUID(), bookID: UUID, readingID: UUID?, text: String, source: String?, includeInJournal: Bool, copiedAt: Date? = nil) {
        self.id = id; self.bookID = bookID; self.readingID = readingID; self.text = text
        self.source = source; self.includeInJournal = includeInJournal; self.copiedAt = copiedAt
    }
}

public struct JournalCorrection: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID; public let readingID: UUID; public let component: JournalComponent
    public let field: String; public let previousValue: String; public let currentValue: String
    public var resolved: Bool
    public init(id: UUID, readingID: UUID, component: JournalComponent, field: String, previousValue: String, currentValue: String, resolved: Bool) {
        self.id = id; self.readingID = readingID; self.component = component; self.field = field
        self.previousValue = previousValue; self.currentValue = currentValue; self.resolved = resolved
    }
}

public struct JournalVolume: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID; public let number: Int; public var archived: Bool
    public let createdAt: Date; public var archivedAt: Date?
    public init(id: UUID, number: Int, archived: Bool, createdAt: Date, archivedAt: Date?) {
        self.id = id; self.number = number; self.archived = archived; self.createdAt = createdAt; self.archivedAt = archivedAt
    }
}

public struct JournalUsage: Equatable, Sendable {
    public let volume: JournalVolume; public let bookReviews: Int; public let readingLogBooks: Int
    public let favorites: Int; public let quotes: Int
    public var bookReviewsRemaining: Int { max(0, JournalRules.bookReviewCapacity - bookReviews) }
    public init(volume: JournalVolume, bookReviews: Int, readingLogBooks: Int, favorites: Int, quotes: Int) {
        self.volume = volume; self.bookReviews = bookReviews; self.readingLogBooks = readingLogBooks
        self.favorites = favorites; self.quotes = quotes
    }
}

public struct BookReviewDraft: Sendable {
    public let summary: String; public let pageCount: Int?; public let rating: Rating
    public let format: JournalFormat; public let start: ReadingDate?; public let finish: ReadingDate?
    public init(summary: String, pageCount: Int?, rating: Rating, format: JournalFormat, start: ReadingDate?, finish: ReadingDate?) {
        self.summary = summary; self.pageCount = pageCount; self.rating = rating
        self.format = format; self.start = start; self.finish = finish
    }
}

public enum JournalError: Error, Equatable { case missingEntry, invalidSummary, invalidQuote, notReady, volumeNotFull }

public extension JournalRules {
    static let readingLogPerPage = 20
    static let favoriteCapacity = 150
    static let favoritesPerPage = 15
    static let quotesPerPage = 6
    static func bookReviewReady(summary: String?, rating: Rating, format: JournalFormat?) -> Bool {
        guard let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, format != nil else { return false }
        if case .unknown = rating { return false }
        return true
    }
}

public struct UnavailableSummaryAssistant: SummaryAssistant {
    public init() {}
    public func draft(bookID: UUID, approvedContext: String) async throws -> String { throw SummaryAssistantError.unavailable }
}
public enum SummaryAssistantError: Error { case unavailable }

public protocol JournalRepository: Sendable {
    func journalInbox() throws -> [JournalInboxItem]
    func journalEntry(readingID: UUID) throws -> JournalEntry
    func saveBookReview(readingID: UUID, draft: BookReviewDraft) throws
    func setFavorite(bookID: UUID, decision: JournalDecision) throws
    func favoriteDecision(bookID: UUID) throws -> JournalDecision
    func quotes(bookID: UUID) throws -> [JournalQuote]
    func saveQuote(_ quote: JournalQuote) throws
    func deleteQuote(id: UUID) throws
    func markQuoteCopied(id: UUID) throws
    func markFavoriteCopied(bookID: UUID, readingID: UUID) throws
    func setNoQuote(readingID: UUID, value: Bool) throws
    func readyForSession() throws -> [JournalInboxItem]
    func markBookReviewCopied(readingID: UUID) throws
    func corrections() throws -> [JournalCorrection]
    func resolveCorrection(id: UUID) throws
    func journalUsage() throws -> JournalUsage
    func archiveFullVolume() throws
}
