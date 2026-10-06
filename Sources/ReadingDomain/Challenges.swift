import Foundation

public enum ChallengeKind: String, Codable, CaseIterable, Sendable {
    case seasonal, tropes, archetype, world, monthly, alphabet, weeks, hundred, roulette
    public var name: String { switch self {
    case .seasonal: "Seasonal Challenge"; case .tropes: "Tropes Challenge"
    case .archetype: "Archetype Challenge"; case .world: "Around the World"
    case .monthly: "Monthly Challenge"; case .alphabet: "Alphabet Challenge"
    case .weeks: "52 Weeks"; case .hundred: "100 Books"; case .roulette: "Reading Roulette"
    } }
    public var semantic: Bool { ![Self.alphabet, .weeks, .hundred].contains(self) }
}
public struct ChallengePrompt: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let challenge: ChallengeKind
    public let key: String
    public let text: String?
    public let order: Int
    public let month: Int?
    public let months: [Int]?
    public init(id: UUID = UUID(), challenge: ChallengeKind, key: String, text: String?, order: Int, month: Int? = nil, months: [Int]? = nil) {
        self.id = id; self.challenge = challenge; self.key = key; self.text = text
        self.order = order; self.month = month; self.months = months
    }
    public var available: Bool { text != nil }
    public var group: String? {
        if let month { return Calendar(identifier: .gregorian).monthSymbols[month - 1] }
        if challenge == .seasonal { return String(key.split(separator: ".")[0]).capitalized }
        if challenge == .world { return key.hasPrefix("easy") ? "Easy" : "Challenge" }
        return nil
    }
}
public struct ChallengeConfiguration: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let year: Int
    public let version: ChallengeVersion
    public let catalogRevision: String
    public let prompts: [ChallengePrompt]
    public init(id: UUID = UUID(), year: Int, catalogRevision: String, prompts: [ChallengePrompt]) {
        self.id = id; self.year = year; version = ChallengeRules.version(year: year)
        self.catalogRevision = catalogRevision; self.prompts = prompts
    }
}
public enum ChallengeCatalog {
    public static func configuration(year: Int) throws -> ChallengeConfiguration {
        guard (1...9999).contains(year) else { throw DomainError.invalidDate }
        struct Entry: Decodable { let challenge: ChallengeKind; let key: String; let text: String?; let order: Int; let month: Int?; let months: [Int]? }
        let url = Bundle.module.url(forResource: "challenge_catalog_v2", withExtension: "json")!
        let catalog = try JSONDecoder().decode([String: [Entry]].self, from: Data(contentsOf: url))
        let entries = catalog[ChallengeRules.version(year: year).rawValue]!
        return ChallengeConfiguration(year: year, catalogRevision: "authoritative-v2", prompts: entries.map {
            ChallengePrompt(challenge: $0.challenge, key: $0.key, text: $0.text, order: $0.order, month: $0.month, months: $0.months)
        })
    }
}
public struct ChallengeReading: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { reading.id }
    public let book: Book
    public let reading: ReadingInstance
    public let seriesIDs: [UUID]
    public init(book: Book, reading: ReadingInstance, seriesIDs: [UUID] = []) {
        self.book = book; self.reading = reading; self.seriesIDs = seriesIDs
    }
}
public struct ChallengeEvidence: Codable, Equatable, Sendable {
    public let fingerprint: String
    public let source: String
    public let reference: String
    public let explanation: String
    public let reliable: Bool
    public init(fingerprint: String, source: String, reference: String, explanation: String, reliable: Bool) {
        self.fingerprint = fingerprint; self.source = source; self.reference = reference; self.explanation = explanation; self.reliable = reliable
    }
    public var usable: Bool { reliable && [fingerprint,source,reference,explanation].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
}
public struct ChallengeProposal: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let readingID: UUID
    public let promptID: UUID
    public let confidence: Int
    public let evidence: ChallengeEvidence
    public init(id: UUID = UUID(), readingID: UUID, promptID: UUID, confidence: Int, evidence: ChallengeEvidence) {
        self.id = id; self.readingID = readingID; self.promptID = promptID; self.confidence = confidence; self.evidence = evidence
    }
    public var percentage: String { "\(confidence)% MATCH" }
}
public struct ChallengeAssignment: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let readingID: UUID
    public let promptID: UUID
    public let bookID: UUID
    public let source: String
    public let confidence: Int?
    public let evidence: ChallengeEvidence?
    public init(id: UUID = UUID(), readingID: UUID, promptID: UUID, bookID: UUID, source: String, confidence: Int? = nil, evidence: ChallengeEvidence? = nil) {
        self.id = id; self.readingID = readingID; self.promptID = promptID; self.bookID = bookID; self.source = source; self.confidence = confidence; self.evidence = evidence
    }
}
public struct ChallengeYearState: Sendable {
    public let configuration: ChallengeConfiguration
    public let assignments: [ChallengeAssignment]
    public let proposals: [ChallengeProposal]
    public let readings: [ChallengeReading]
    public let hasAnalysis: Bool
    public init(configuration: ChallengeConfiguration, assignments: [ChallengeAssignment], proposals: [ChallengeProposal], readings: [ChallengeReading], hasAnalysis: Bool = false) {
        self.configuration = configuration; self.assignments = assignments; self.proposals = proposals; self.readings = readings; self.hasAnalysis = hasAnalysis
    }
    public func eligibleForManual(_ record: ChallengeReading, prompt: ChallengePrompt) -> Bool {
        guard ChallengeRules.eligible(record, prompt: prompt, year: configuration.year) else { return false }
        if prompt.challenge == .hundred {
            return !assignments.contains { assignment in assignment.readingID == record.id && configuration.prompts.contains { $0.id == assignment.promptID && $0.challenge == .hundred } }
        }
        if prompt.challenge == .alphabet {
            for seriesID in record.seriesIDs {
                let books = Set(assignments.compactMap { assignment -> UUID? in
                    guard configuration.prompts.contains(where: { $0.id == assignment.promptID && $0.challenge == .alphabet }), let assigned = readings.first(where: { $0.id == assignment.readingID }), assigned.seriesIDs.contains(seriesID) else { return nil }
                    return assigned.book.id
                })
                if books.count >= 2 { return false }
            }
        }
        return true
    }
    public var assignmentsNeedingReview: [ChallengeAssignment] {
        assignments.filter { assignment in
            guard let record = readings.first(where: { $0.id == assignment.readingID }), let prompt = configuration.prompts.first(where: { $0.id == assignment.promptID }) else { return true }
            return !ChallengeRules.eligible(record, prompt: prompt, year: configuration.year)
        }
    }
    public func assignment(_ prompt: ChallengePrompt) -> ChallengeAssignment? { assignments.first { $0.promptID == prompt.id } }
    public func bookTitle(readingID: UUID) -> String { readings.first { $0.id == readingID }?.book.title ?? "Book unavailable" }
}
public enum ChallengeError: Error, Equatable, Sendable {
    case unavailablePrompt, ineligibleReading, invalidEvidence, occupied, staleProposal, seriesLimit, assistantUnavailable, ambiguousFinishOrder
}
public protocol ChallengeAssistant: Sendable {
    func explain(proposal: ChallengeProposal, approvedContext: String) async throws -> ChallengeEvidence
}
public struct UnavailableChallengeAssistant: ChallengeAssistant {
    public init() {}
    public func explain(proposal: ChallengeProposal, approvedContext: String) async throws -> ChallengeEvidence { throw ChallengeError.assistantUnavailable }
}
public protocol ChallengeMatcher: Sendable {
    func analyze(reading: ChallengeReading, freePrompts: [ChallengePrompt]) async throws -> [ChallengeProposal]
}
public struct UnavailableChallengeMatcher: ChallengeMatcher {
    public init() {}
    public func analyze(reading: ChallengeReading, freePrompts: [ChallengePrompt]) async throws -> [ChallengeProposal] { throw ChallengeError.assistantUnavailable }
}
public protocol ChallengesRepository: Sendable {
    func challengeYear(year: Int) throws -> ChallengeYearState
    func challengeYears() throws -> [Int]
    func ensureChallengeYear(year: Int) throws
    func storeChallengeProposals(_ proposals: [ChallengeProposal], year: Int) throws
    func confirmChallengeProposal(id: UUID, year: Int) throws
    func rejectChallengeProposal(id: UUID, year: Int) throws
    func assignChallenge(promptID: UUID, readingID: UUID, year: Int) throws
    func replaceChallengeWeek(promptID: UUID, readingID: UUID, year: Int, confirmed: Bool) throws
    func removeChallengeAssignment(id: UUID, year: Int, confirmed: Bool) throws
    func markChallengesCopied(readingID: UUID) throws
}
public extension ChallengeRules {
    static func eligible(_ record: ChallengeReading, prompt: ChallengePrompt, year: Int, automatic: Bool = false) -> Bool {
        guard prompt.available, record.reading.status == .read, !automatic || !record.reading.historical else { return false }
        guard let date = record.reading.finishDate else {
            // An explicit year/manual decision does not fabricate a finish date.
            // Period-bound prompts still require the real date to establish eligibility.
            return !automatic && ![ChallengeKind.seasonal,.monthly,.weeks].contains(prompt.challenge)
        }
        if prompt.challenge == .weeks { return date.isoWeek.year == year && String(date.isoWeek.week) == prompt.key }
        guard date.year == year else { return false }
        if let month = prompt.month, month != date.month { return false }
        if let months = prompt.months, !months.contains(date.month) { return false }
        if prompt.challenge == .alphabet { return alphabetLetter(record.book.title) == prompt.text }
        return true
    }
    static func alphabetLetter(_ title: String) -> String? {
        var words = title.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if let first = words.first, ["the","a","an","le","la","les"].contains(first.lowercased()) { words.removeFirst() }
        guard let first = words.first?.first else { return nil }
        let letter = String(first).uppercased(); return "ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(letter) ? letter : nil
    }
    static func best(_ proposals: [ChallengeProposal], prompts: [ChallengePrompt], readings: [ChallengeReading], occupied: Set<UUID>, rejected: Set<String>, year: Int) -> ChallengeProposal? {
        proposals.filter { proposal in
            guard let prompt = prompts.first(where: { $0.id == proposal.promptID }), prompt.challenge.semantic,
                  let record = readings.first(where: { $0.id == proposal.readingID }) else { return false }
            return proposal.evidence.usable && semanticProposalAllowed(confidence: proposal.confidence, reliable: true, occupied: occupied.contains(prompt.id))
                && eligible(record, prompt: prompt, year: year, automatic: true)
                && !rejected.contains(rejectionKey(bookID: record.book.id, promptID: prompt.id, evidence: proposal.evidence))
        }.sorted { $0.confidence == $1.confidence ? $0.id.uuidString < $1.id.uuidString : $0.confidence > $1.confidence }.first
    }
    static func rejectionKey(bookID: UUID, promptID: UUID, evidence: ChallengeEvidence) -> String {
        // JSON is unambiguous and preserves the Book/prompt/material-evidence identity.
        let values = [bookID.uuidString,promptID.uuidString,evidence.source,evidence.reference,evidence.fingerprint]
        return String(data: try! JSONEncoder().encode(values), encoding: .utf8)!
    }
    static func firstFinished(in week: ISOWeek, readings: [ChallengeReading]) -> ChallengeReading? {
        let eligible = readings.filter { $0.reading.status == .read && !$0.reading.historical && $0.reading.finishDate?.isoWeek == week }
        guard let firstDate = eligible.compactMap(\.reading.finishDate).min() else { return nil }
        let first = eligible.filter { $0.reading.finishDate == firstDate }
        // Approved: date-only ties remain manual; no invented chronology.
        return first.count == 1 ? first[0] : nil
    }
}
