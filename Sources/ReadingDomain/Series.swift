import Foundation

public enum PublicationState: String, Codable, Sendable { case published, announced, unconfirmed, unknown }
public enum SeriesEntryKind: String, Codable, Sendable { case main, related, companion }
public enum ReleaseValue: Equatable, Sendable { case exact(ReadingDate), year(Int), unknown }
public struct SeriesEntry: Sendable {
    public let id: UUID
    public let seriesID: UUID
    public let bookID: UUID?
    public let position: Decimal
    public let kind: SeriesEntryKind
    public let publication: PublicationState
    public let release: ReleaseValue
    public let includedInTracker: Bool
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
