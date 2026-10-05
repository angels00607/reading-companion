import Foundation

public enum PublicationState: String, Codable, Sendable { case published, announced, unconfirmed, unknown }
public enum SeriesEntryKind: String, Codable, Sendable { case main, related, companion }
public enum ReleaseValue: Codable, Equatable, Sendable {
    case exact(ReadingDate), year(Int), unknown
}
public struct SeriesEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let seriesID: UUID
    public let bookID: UUID?
    public var title: String
    public let position: Decimal
    public let kind: SeriesEntryKind
    public let publication: PublicationState
    public let release: ReleaseValue
    public var included: Bool
    public var includedInTracker: Bool
    public var isRead: Bool
    public init(id: UUID = UUID(), seriesID: UUID, bookID: UUID?, title: String, position: Decimal,
                kind: SeriesEntryKind, publication: PublicationState, release: ReleaseValue,
                included: Bool = true, includedInTracker: Bool = true, isRead: Bool = false) {
        self.id = id; self.seriesID = seriesID; self.bookID = bookID; self.title = title
        self.position = position; self.kind = kind; self.publication = publication
        self.release = release; self.included = included; self.includedInTracker = includedInTracker
        self.isRead = isRead
    }
}

public struct ReadingSeries: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let ownerID: UUID
    public var name: String
    public var author: String?
    public var userStatusOverride: SeriesStatus?
    public var evidence: SeriesStatusEvidence
    public var finalTotalKnown: Bool
    public var updatedAt: Date
    public init(id: UUID = UUID(), ownerID: UUID, name: String, author: String? = nil,
                userStatusOverride: SeriesStatus? = nil, evidence: SeriesStatusEvidence = .init(),
                finalTotalKnown: Bool = false, updatedAt: Date = Date()) {
        self.id = id; self.ownerID = ownerID; self.name = name; self.author = author
        self.userStatusOverride = userStatusOverride; self.evidence = evidence
        self.finalTotalKnown = finalTotalKnown; self.updatedAt = updatedAt
    }
    public var effectiveStatus: SeriesStatus { SeriesRules.effectiveStatus(override: userStatusOverride, evidence: evidence) }
}

public struct SeriesDetail: Equatable, Sendable {
    public let series: ReadingSeries
    public let entries: [SeriesEntry]
    public init(series: ReadingSeries, entries: [SeriesEntry]) {
        self.series = series; self.entries = SeriesRules.ordered(entries)
    }
    public var confirmedTotal: Int { SeriesRules.confirmedTotal(entries) }
    public var readConfirmed: Int { SeriesRules.confirmedEntries(entries).filter(\.isRead).count }
    public var nextBook: SeriesEntry? { SeriesRules.nextBook(entries) }
    public var trackerMapping: SeriesTrackerMapping { SeriesRules.trackerMapping(entries: entries) }
}

public enum SeriesSort: String, CaseIterable, Codable, Sendable {
    case recentlyUpdated = "Recently updated", alphabetical = "Alphabetical", progress = "Progress", recentlyRead = "Recently read"
}
public enum SeriesFilter: String, CaseIterable, Codable, Sendable {
    case all = "All", active = "Active", waiting = "Waiting", completed = "Completed", abandoned = "Abandoned", needsAttention = "Needs Attention"
}
public enum SeriesTrackerType: String, Codable, Sendable { case type1 = "Type 1", type2 = "Type 2", type3 = "Type 3" }
public struct SeriesTrackerMapping: Equatable, Sendable {
    public let type: SeriesTrackerType; public let entryCount: Int; public let continuationPages: Int
    public init(type: SeriesTrackerType, entryCount: Int, continuationPages: Int) {
        self.type = type; self.entryCount = entryCount; self.continuationPages = continuationPages
    }
}
public struct SeriesChangeProposal: Equatable, Identifiable, Sendable {
    public let id: UUID; public let seriesID: UUID; public let field: String
    public let current: String; public let proposed: String; public let source: String
    public let evidenceFingerprint: String
    public init(id: UUID, seriesID: UUID, field: String, current: String, proposed: String, source: String, evidenceFingerprint: String) {
        self.id = id; self.seriesID = seriesID; self.field = field; self.current = current
        self.proposed = proposed; self.source = source; self.evidenceFingerprint = evidenceFingerprint
    }
}
public protocol SeriesRepository: Sendable {
    func series(query: String, filter: SeriesFilter, sort: SeriesSort) throws -> [SeriesDetail]
    func seriesDetail(id: UUID) throws -> SeriesDetail
    func saveSeries(_ series: ReadingSeries, entries: [SeriesEntry]) throws
    func setStatusOverride(seriesID: UUID, status: SeriesStatus?) throws
    func setTrackerInclusion(entryID: UUID, included: Bool) throws
    func proposals(seriesID: UUID?) throws -> [SeriesChangeProposal]
    func propose(seriesID: UUID, field: String, current: String, proposed: String, source: String, evidenceFingerprint: String) throws
    func acceptProposal(id: UUID) throws
    func rejectProposal(id: UUID) throws
    func setSeriesJournalReady(readingID: UUID, ready: Bool) throws
}
public struct ChallengeYearSnapshot: Sendable {
    public let year: Int
    public let version: ChallengeVersion
    public let catalogRevision: String
    public let prompts: [ChallengePromptSnapshot]
    public init(year: Int, catalogRevision: String, prompts: [ChallengePromptSnapshot]) {
        self.year = year; version = ChallengeRules.version(year: year)
        self.catalogRevision = catalogRevision; self.prompts = prompts
    }
}
public struct ChallengePromptSnapshot: Sendable {
    public let key: String
    public let text: String?
    public let isTBD: Bool
}
