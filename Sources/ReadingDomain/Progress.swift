import Foundation

public enum ProgressMode: String, Codable, Sendable { case page, percentage }

/// Validated explicit progress. Unknown values are allowed; mixed units are not.
/// Page-mode total is a genuine denominator, never a conversion basis for percentage.
public struct ReadingProgress: Codable, Equatable, Sendable {
    public let mode: ProgressMode
    public let currentPage: Int?
    public let totalPages: Int?
    public let percentage: Double?
    private init(mode: ProgressMode, currentPage: Int?, totalPages: Int?, percentage: Double?) {
        self.mode = mode; self.currentPage = currentPage
        self.totalPages = totalPages; self.percentage = percentage
    }
    public static func pages(current: Int? = nil, total: Int? = nil) throws -> Self {
        guard current.map({ $0 >= 0 }) ?? true, total.map({ $0 > 0 }) ?? true,
              !(current != nil && total != nil && current! > total!) else { throw DomainError.invalidProgress }
        return Self(mode: .page, currentPage: current, totalPages: total, percentage: nil)
    }
    public static func percentage(_ value: Double? = nil) throws -> Self {
        guard value.map({ $0.isFinite && (0...100).contains($0) }) ?? true else { throw DomainError.invalidProgress }
        return Self(mode: .percentage, currentPage: nil, totalPages: nil, percentage: value)
    }
    public var hasValue: Bool { currentPage != nil || percentage != nil }
    /// A confirmation hint only; this property cannot change reading status.
    public var suggestsFinishConfirmation: Bool {
        switch mode {
        case .page: return currentPage != nil && totalPages != nil && currentPage == totalPages
        case .percentage: return percentage == 100
        }
    }
    private enum CodingKeys: String, CodingKey { case mode, currentPage, totalPages, percentage }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mode = try container.decode(ProgressMode.self, forKey: .mode)
        let page = try container.decodeIfPresent(Int.self, forKey: .currentPage)
        let total = try container.decodeIfPresent(Int.self, forKey: .totalPages)
        let percent = try container.decodeIfPresent(Double.self, forKey: .percentage)
        switch mode {
        case .page:
            guard percent == nil else { throw DomainError.invalidProgress }
            self = try .pages(current: page, total: total)
        case .percentage:
            guard page == nil && total == nil else { throw DomainError.invalidProgress }
            self = try .percentage(percent)
        }
    }
}

public struct ProgressObservation: Codable, Equatable, Sendable {
    public let id: UUID
    public let readingID: UUID
    public let expectedRevision: Int
    public let value: ReadingProgress
    public let previous: ReadingProgress?
    public let recordedAt: Date
    public let requiresReview: Bool
    public init(id: UUID, readingID: UUID, expectedRevision: Int, value: ReadingProgress,
                previous: ReadingProgress?, recordedAt: Date, requiresReview: Bool) {
        self.id = id; self.readingID = readingID; self.expectedRevision = expectedRevision
        self.value = value; self.previous = previous; self.recordedAt = recordedAt; self.requiresReview = requiresReview
    }
    /// Unknown for percentage, unresolved conflicts, or missing prior page position.
    public var genuinePageDelta: Int? {
        guard !requiresReview, value.mode == .page, previous?.mode == .page,
              let new = value.currentPage, let old = previous?.currentPage else { return nil }
        return new - old
    }
}
public enum ProgressUpdateResult: Equatable, Sendable {
    case applied(ProgressObservation)
    case requiresReview(ProgressObservation)
}
public enum ProgressRules {
    public static func record(_ reading: inout ReadingInstance, value: ReadingProgress,
                              expectedRevision: Int, observationID: UUID = UUID(),
                              recordedAt: Date = Date()) throws -> ProgressUpdateResult {
        guard reading.status == .currentlyReading, value.hasValue else { throw DomainError.invalidTransition }
        if let prior = reading.progressObservations.first(where: { $0.id == observationID }) {
            guard prior.value == value && prior.expectedRevision == expectedRevision else { throw DomainError.invalidProgress }
            return prior.requiresReview ? .requiresReview(prior) : .applied(prior)
        }
        // Concurrent or different-unit observations are retained, never chosen by maximum or time.
        let conflict = expectedRevision != reading.revision || value.mode != reading.progress.mode
        let observation = ProgressObservation(id: observationID, readingID: reading.id,
            expectedRevision: expectedRevision, value: value, previous: conflict ? nil : reading.progress,
            recordedAt: recordedAt, requiresReview: conflict)
        reading.progressObservations.append(observation)
        if conflict { return .requiresReview(observation) }
        reading.progress = value; reading.revision += 1
        return .applied(observation)
    }
    /// Explicit mode selection clears current position to unknown; historical values are untouched.
    /// No page/percentage conversion or synthetic observation is performed.
    public static func selectMode(_ mode: ProgressMode, reading: inout ReadingInstance,
                                  expectedRevision: Int) throws {
        guard expectedRevision == reading.revision else { throw DomainError.staleRevision }
        guard reading.status == .currentlyReading else { throw DomainError.invalidTransition }
        guard mode != reading.progress.mode else { return }
        reading.progress = try mode == .page ? .pages() : .percentage()
        reading.revision += 1
    }
    public static func pagesReadFromObservations(_ reading: ReadingInstance) -> Int? {
        guard reading.status != .dnf else { return nil }
        let deltas = reading.progressObservations.compactMap(\.genuinePageDelta)
        return deltas.isEmpty ? nil : deltas.reduce(0, +)
    }
}
