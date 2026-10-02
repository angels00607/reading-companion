import Foundation

public enum BooksError: Error, Equatable, Sendable {
    case requiredMetadata, duplicateNeedsReview([UUID]), missingRecord, invalidMetadata, activeReadingExists
}
public struct WorkCandidate: Codable, Equatable, Identifiable, Sendable {
    public var id: String { provider + ":" + reference }
    public let provider: String
    public let reference: String
    public var title: String?
    public var author: String?
    public var synopsis: String?
    public var coverReference: String?
    public init(provider: String, reference: String, title: String?, author: String?, synopsis: String? = nil, coverReference: String? = nil) {
        self.provider = provider; self.reference = reference; self.title = title; self.author = author
        self.synopsis = synopsis; self.coverReference = coverReference
    }
}
public struct EditionCandidate: Codable, Equatable, Identifiable, Sendable {
    public var id: String { provider + ":" + reference }
    public let provider: String
    public let reference: String
    public var title: String?
    public var language: String?
    public var isbn10: String?
    public var isbn13: String?
    public var pageCount: Int?
    public var publisher: String?
    public var coverReference: String?
    public init(provider: String, reference: String, title: String? = nil, language: String? = nil,
                isbn10: String? = nil, isbn13: String? = nil, pageCount: Int? = nil,
                publisher: String? = nil, coverReference: String? = nil) {
        self.provider = provider; self.reference = reference; self.title = title; self.language = language
        self.isbn10 = isbn10; self.isbn13 = isbn13; self.pageCount = pageCount
        self.publisher = publisher; self.coverReference = coverReference
    }
    // Binding and format are deliberately absent from every external candidate.
}
public protocol BooksCatalogProvider: BookMetadataProvider {
    func searchWorks(query: String) async throws -> [WorkCandidate]
    func editions(for work: WorkCandidate) async throws -> [EditionCandidate]
    func refresh(work: WorkCandidate) async throws -> WorkCandidate
}
public extension BooksCatalogProvider {
    func search(query: String, preferredLanguage: String) async throws -> [MetadataCandidate] {
        try await searchWorks(query: query).map { work in
            MetadataCandidate(providerID: work.reference, title: work.title, author: work.author, language: nil, pageCount: nil,
                provenance: Provenance(origin: .provider, sourceReference: work.provider + ":" + work.reference, evidenceFingerprint: nil, userOverridden: false))
        }
    }
}
public enum LibraryView: String, CaseIterable, Sendable { case all = "All", toRead = "To Read", read = "Read" }
public enum LibrarySort: String, CaseIterable, Sendable {
    case recentlyAdded = "Recently Added", title = "Title A–Z", titleDescending = "Title Z–A"
    case author = "Author A–Z", authorDescending = "Author Z–A"
    case pages = "Pages shortest", pagesDescending = "Pages longest"
    case recentlyFinished = "Recently Finished", oldest = "Oldest", rating = "Rating"
}
public struct LibraryFilters: Sendable {
    public var status: ReadingStatus?
    public var year: Int?
    public var rating: Int?
    public var genre: String?
    public var format: JournalFormat?
    public var inSeries: Bool?
    public init() {}
}
public enum DuplicateChoice: Sendable { case review, reuse(UUID), addAnyway }
public enum LibraryAddition: Sendable {
    case toRead
    case currentlyReading(mode: ProgressMode, date: ReadingDate?)
    case alreadyRead(date: ReadingDate?, rating: Rating)
}
public struct CatalogRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { book.id }
    public let book: Book
    public var editions: [Edition]
    public var readings: [ReadingInstance]
    public var wantsToRead: Bool
    public var coverReference: String?
    public var synopsis: String?
    public var seriesName: String?
    public var genreSuggestion: String?
    public var revision: Int
    public init(book: Book, editions: [Edition], readings: [ReadingInstance], wantsToRead: Bool,
                coverReference: String?, synopsis: String?, seriesName: String?, genreSuggestion: String?, revision: Int) {
        self.book = book; self.editions = editions; self.readings = readings; self.wantsToRead = wantsToRead
        self.coverReference = coverReference; self.synopsis = synopsis; self.seriesName = seriesName
        self.genreSuggestion = genreSuggestion; self.revision = revision
    }
    public var active: ReadingInstance? { readings.first { $0.status == .currentlyReading } }
    public var latest: ReadingInstance? { readings.first }
    public var completedCount: Int { readings.filter { $0.status == .read }.count }
    public var statusLabel: String {
        if active != nil { return "Currently Reading" }
        if wantsToRead { return "To Read" }
        if completedCount > 0 { return completedCount > 1 ? "Read \(completedCount)×" : "Read" }
        if latest?.status == .dnf { return "DNF" }
        return wantsToRead ? "To Read" : "In Library"
    }
}
public enum BookField: String, CaseIterable, Codable, Sendable {
    case title, author, cover, synopsis, series, genreSuggestion
}
public struct MetadataReview: Identifiable, Sendable {
    public let id: UUID
    public let bookID: UUID
    public let field: BookField
    public let current: String?
    public let proposed: String?
    public let source: String
    public init(id: UUID, bookID: UUID, field: BookField, current: String?, proposed: String?, source: String) {
        self.id = id; self.bookID = bookID; self.field = field; self.current = current; self.proposed = proposed; self.source = source
    }
}
public enum BooksRules {
    public static func validatedText(_ value: String?) throws -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw BooksError.requiredMetadata }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public static func pageIncrement(_ amount: Int, reading: ReadingInstance) throws -> ReadingProgress {
        guard reading.progress.mode == .page, let current = reading.progress.currentPage,
              amount > 0, current <= Int.max - amount else { throw DomainError.invalidProgress }
        return try .pages(current: current + amount, total: reading.progress.totalPages)
    }
    public static func editionsEnglishFirst(_ editions: [EditionCandidate]) -> [EditionCandidate] {
        editions.sorted { a, b in
            let aRank = a.language == "en" ? 0 : 1; let bRank = b.language == "en" ? 0 : 1
            return aRank == bRank ? a.id < b.id : aRank < bRank
        }
    }
}

public protocol BooksRepository: Sendable {
    func library(query: String, view: LibraryView, sort: LibrarySort, filters: LibraryFilters, limit: Int, offset: Int) throws -> [CatalogRecord]
    func record(id: UUID) throws -> CatalogRecord
    func add(work: WorkCandidate, edition: EditionCandidate?, choice: DuplicateChoice) throws -> UUID
    func addWithIntent(work: WorkCandidate, edition: EditionCandidate?, choice: DuplicateChoice, intent: LibraryAddition, manualValues: [BookField: String]) throws -> UUID
    func start(bookID: UUID, editionID: UUID?, mode: ProgressMode, date: ReadingDate?) throws -> UUID
    func recordCompleted(bookID: UUID, editionID: UUID?, date: ReadingDate?, rating: Rating) throws -> UUID
    func providerWorks(bookID: UUID) throws -> [WorkCandidate]
    func update(readingID: UUID, value: ReadingProgress, revision: Int, observationID: UUID) throws -> ProgressUpdateResult
    func finish(readingID: UUID, confirmed: Bool, date: ReadingDate?, revision: Int) throws
    func markDNF(readingID: UUID, revision: Int) throws
    func resume(readingID: UUID, revision: Int) throws
    func edit(bookID: UUID, values: [BookField: String?], revision: Int) throws
    func editEdition(_ edition: Edition, revision: Int) throws
    func editInfo(bookID: UUID, values: [BookField: String?], edition: Edition?, revision: Int) throws
    func editReading(readingID: UUID, start: ReadingDate?, finish: ReadingDate?, rating: Rating, genre: String?, format: JournalFormat?, revision: Int) throws
    func reviewProvider(bookID: UUID, work: WorkCandidate) throws
    func proposals(bookID: UUID) throws -> [MetadataReview]
    func decide(proposalID: UUID, accept: Bool) throws
    func resolveProgress(readingID: UUID, observationID: UUID, apply: Bool, revision: Int) throws
}
