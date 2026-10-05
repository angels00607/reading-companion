import Foundation

public struct CompletionEffects: Equatable, Sendable {
    public let journalInbox: Bool
    public let challengeAnalysis: Bool
    public let rewardEligible: Bool
}
public enum ReadingRules {
    public static func finish(_ reading: inout ReadingInstance, confirmed: Bool,
                              date: ReadingDate?, expectedRevision: Int) throws -> CompletionEffects {
        guard reading.revision == expectedRevision else { throw DomainError.staleRevision }
        guard confirmed else { throw DomainError.confirmationRequired }
        guard reading.status == .currentlyReading else { throw DomainError.invalidTransition }
        reading.status = .read; reading.finishDate = date; reading.revision += 1
        return CompletionEffects(journalInbox: !reading.historical,
            challengeAnalysis: !reading.historical, rewardEligible: !reading.historical)
    }
    public static func markDNF(_ reading: inout ReadingInstance) throws {
        guard reading.status == .currentlyReading else { throw DomainError.invalidTransition }
        reading.status = .dnf; reading.revision += 1
    }
    public static func resume(_ reading: inout ReadingInstance) throws {
        guard reading.status == .dnf else { throw DomainError.invalidTransition }
        reading.status = .currentlyReading; reading.revision += 1
    }
    public static func includedInCompletedStats(_ reading: ReadingInstance) -> Bool { reading.status == .read }
    public static func setJournalFormat(_ format: JournalFormat, origin: MutationOrigin,
                                       reading: inout ReadingInstance) throws {
        guard origin == .user else { throw DomainError.externalFormatForbidden }
        reading.journalFormat = format
    }
}
public enum JournalComponentStatus: String, Codable, Sendable { case pending, ready, copied, none }
public enum JournalRules {
    public static let bookReviewCapacity = 100
    public static func mayGenerateCompletionWork(status: ReadingStatus, origin: MutationOrigin) -> Bool {
        status != .dnf && origin != .historicalImport
    }
    public static func inCompletionFlow(status: ReadingStatus) -> Bool { status == .read }
    public static func bookReviewReady(requiredFieldsPresent: Bool, format: JournalFormat?) -> Bool {
        requiredFieldsPresent && format != nil
    }
    public static func correctionRequired<Value: Equatable>(copied: Value?, current: Value) -> Bool {
        copied.map { $0 != current } ?? false
    }
}
public enum ChallengeVersion: String, Codable, Sendable { case a = "A", b = "B" }
public enum ChallengeRules {
    public static func version(year: Int) -> ChallengeVersion { year.isMultiple(of: 2) ? .a : .b }
    public static func semanticProposalAllowed(confidence: Int, reliable: Bool, occupied: Bool) -> Bool {
        reliable && (70...100).contains(confidence) && !occupied
    }
    public static func sameWeek(_ first: ReadingDate, _ second: ReadingDate) -> Bool {
        first.isoWeek == second.isoWeek
    }
    // Catalog holes are unavailable, never synthesized prompts.
    public static func promptEligible(isTBD: Bool) -> Bool { !isTBD }
}
public enum SeriesStatus: String, Codable, Sendable { case active, waiting, completed, abandoned, unknown }
public enum SeriesRules {
    public static func effectiveStatus(override: SeriesStatus?, evidence: SeriesStatusEvidence) -> SeriesStatus {
        if let override { return override }
        if evidence.hasUnreadIncludedPublished == true { return .active }
        if evidence.allIncludedConfirmedRead == true && evidence.confirmedComplete == true { return .completed }
        if evidence.allIncludedPublishedRead == true && evidence.confirmedComplete != true
            && (evidence.hasAnnouncedOrExpectedFutureEntry == true || evidence.knownOngoing == true) {
            return .waiting
        }
        return .unknown
    }
    public static func trackerPages(entryCount: Int) -> Int {
        max(1, (entryCount + 19) / 20)
    }
    public static func ordered(_ entries: [SeriesEntry]) -> [SeriesEntry] {
        entries.sorted { $0.position == $1.position ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending : $0.position < $1.position }
    }
    public static func confirmedEntries(_ entries: [SeriesEntry]) -> [SeriesEntry] {
        entries.filter { $0.publication == .published || $0.publication == .announced }
    }
    public static func confirmedTotal(_ entries: [SeriesEntry]) -> Int { confirmedEntries(entries).count }
    public static func nextBook(_ entries: [SeriesEntry]) -> SeriesEntry? {
        ordered(entries).first { $0.included && !$0.isRead && $0.publication == .published }
    }
    public static func trackerMapping(entries: [SeriesEntry]) -> SeriesTrackerMapping {
        let count = entries.filter(\.includedInTracker).count
        if count <= 5 { return .init(type: .type1, entryCount: count, continuationPages: 0) }
        if count <= 10 { return .init(type: .type2, entryCount: count, continuationPages: 0) }
        return .init(type: .type3, entryCount: count, continuationPages: max(0, (count - 1) / 20))
    }
}
public struct XPAward: Equatable, Sendable {
    public let semanticKey: String
    public let amount: Int
    public init(semanticKey: String, amount: Int) throws {
        guard !semanticKey.isEmpty, amount >= 0 else { throw DomainError.invalidProgress }
        self.semanticKey = semanticKey; self.amount = amount
    }
}
public enum XPPolicy {
    public static func merge(existing: [XPAward], restored: [XPAward]) throws -> [XPAward] {
        var awards = [String: XPAward]()
        for award in existing + restored {
            if let prior = awards[award.semanticKey], prior.amount != award.amount {
                throw DomainError.staleRevision // Review invalid/conflicting award evidence; never reduce silently.
            }
            awards[award.semanticKey] = award
        }
        return awards.values.sorted { $0.semanticKey < $1.semanticKey }
    }
}
