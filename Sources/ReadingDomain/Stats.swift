import Foundation

public enum StatsPeriod: Equatable, Sendable {
    case month(year: Int, month: Int), year(Int), lifetime, volume(startYear: Int)
    public var key: String {
        switch self {
        case let .month(y,m): String(format: "%04d-%02d",y,m)
        case let .year(y): String(format: "%04d",y)
        case .lifetime: "lifetime"
        case let .volume(y): "volume-\(y)"
        }
    }
    public var selectionScope: String? { switch self { case .month: "month"; case .year: "year"; default: nil } }
    public var year: Int? { switch self { case let .month(y,_), let .year(y): y; default: nil } }
    public func contains(_ date: ReadingDate?) -> Bool {
        if self == .lifetime { return true }
        guard let date else { return false }
        switch self {
        case let .month(y,m): return date.year == y && date.month == m
        case let .year(y): return date.year == y
        case let .volume(y): return (y...min(9999,y+4)).contains(date.year)
        case .lifetime: return true
        }
    }
    public var valid: Bool {
        switch self {
        case let .month(y,m): (1...9999).contains(y) && (1...12).contains(m)
        case let .year(y): (1...9999).contains(y)
        case let .volume(y): (1...9995).contains(y)
        case .lifetime: true
        }
    }
}

/// A batch-loaded projection of stored truth. Edition metadata is deliberately absent.
public struct StatsReading: Identifiable, Sendable {
    public let id: UUID; public let bookID: UUID
    public let title: String; public let author: String; public let coverReference: String?
    public let status: ReadingStatus; public let finish: ReadingDate?; public let rating: Rating
    public let genre: String?; public let format: JournalFormat?
    public let observedPages: Int?; public let pageCoverageComplete: Bool
    public let activityDates: [ReadingDate]
    public init(id: UUID, bookID: UUID, title: String, author: String = "", coverReference: String? = nil,
                status: ReadingStatus = .read, finish: ReadingDate?, rating: Rating = .unknown,
                genre: String? = nil, format: JournalFormat? = nil, observedPages: Int? = nil,
                pageCoverageComplete: Bool = false, activityDates: [ReadingDate] = []) {
        self.id=id; self.bookID=bookID; self.title=title; self.author=author; self.coverReference=coverReference
        self.status=status; self.finish=finish; self.rating=rating; self.genre=genre; self.format=format
        self.observedPages=observedPages; self.pageCoverageComplete=pageCoverageComplete; self.activityDates=activityDates
    }
}
public struct StatsQuantity: Equatable, Sendable {
    public let known: Int?
    public let coveredReadings: Int
    public let totalReadings: Int
    public let complete: Bool
    public var display: String {
        guard let known else { return "Unknown" }
        return known.formatted() + (complete ? "" : " recorded")
    }
}
public struct StatsCategory: Identifiable, Sendable {
    public var id: String { label }; public let label: String; public let count: Int
}
public struct StatsTimePoint: Identifiable, Sendable {
    public let id: String; public let label: String; public let count: Int?
}
public struct BestBookSelection: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID; public let scope: String; public let period: String
    public let readingID: UUID?; public let revision: Int
    public init(id: UUID, scope: String, period: String, readingID: UUID?, revision: Int) {
        self.id=id; self.scope=scope; self.period=period; self.readingID=readingID; self.revision=revision
    }
}
public struct StatsSnapshot: Sendable {
    public let period: StatsPeriod; public let readings: [StatsReading]; public let allReadings: [StatsReading]
    public let books: Int; public let pages: StatsQuantity; public let readingDays: StatsQuantity
    public let averageRating: Double?; public let ratedCount: Int; public let noRatingCount: Int; public let unknownRatingCount: Int
    public let genres: [StatsCategory]; public let formats: [StatsCategory]; public let time: [StatsTimePoint]
    public let undatedCompletions: Int; public let rereads: Int
    public let selection: BestBookSelection?; public let candidates: [StatsReading]; public let selectionNeedsReview: Bool
    public var selected: StatsReading? { allReadings.first { $0.id == selection?.readingID } }
}
public enum StatsError: Error { case invalidPeriod, ineligibleSelection, invalidActivity }
public enum StatsRules {
    public static func snapshot(period: StatsPeriod, readings all: [StatsReading], selections: [BestBookSelection]) -> StatsSnapshot {
        let completed = all.filter { $0.status == .read }
        let items = completed.filter { period.contains($0.finish) }
        let undated = completed.filter { $0.finish == nil }.count
        let knownPages = items.compactMap(\.observedPages)
        let pages = StatsQuantity(known: items.isEmpty ? 0 : knownPages.isEmpty ? nil : knownPages.reduce(0,+),
            coveredReadings: knownPages.count, totalReadings: items.count,
            complete: items.allSatisfy(\.pageCoverageComplete))
        let eligibleActivity = all.filter { $0.status != .dnf }
        let days = Set(eligibleActivity.flatMap(\.activityDates).filter { period.contains($0) }.map(\.isoString))
        // Absence of activity records does not establish absence of reading.
        let activity = StatsQuantity(known: eligibleActivity.isEmpty ? 0 : days.isEmpty ? nil : days.count,
            coveredReadings: eligibleActivity.filter { $0.activityDates.contains(where: period.contains) }.count,
            totalReadings: eligibleActivity.count, complete: eligibleActivity.isEmpty)
        let ratings = items.compactMap { item -> Int? in if case .stars(let s) = item.rating, (1...5).contains(s) { return s }; return nil }
        let noRating = items.filter { $0.rating == .noRating }.count
        func categories(_ values: [String]) -> [StatsCategory] {
            Dictionary(grouping: values, by: { $0 }).map { StatsCategory(label:$0.key,count:$0.value.count) }
                .sorted { $0.count == $1.count ? $0.label < $1.label : $0.count > $1.count }
        }
        let selection = selections.first { $0.scope == period.selectionScope && $0.period == period.key }
        let candidates: [StatsReading]
        if case let .year(y) = period {
            let ids = Set(selections.filter { s in
                s.scope == "month" && s.period.hasPrefix(String(format:"%04d-",y)) &&
                completed.contains { $0.id == s.readingID && $0.finish.map { String(format:"%04d-%02d",$0.year,$0.month) } == s.period }
            }.compactMap(\.readingID))
            candidates = items.filter { ids.contains($0.id) }
        } else { candidates = period.selectionScope == "month" ? items : [] }
        let invalid = selection?.readingID != nil && !candidates.contains { $0.id == selection?.readingID }
        let duplicates = Dictionary(grouping: completed, by: \.bookID)
        let rereadIDs = Set(duplicates.values.flatMap { values -> [UUID] in
            // Missing finish chronology cannot be invented; only dated subsequent occasions are classified.
            let ordered=values.filter { $0.finish != nil }.sorted { $0.finish! < $1.finish! }
            return ordered.dropFirst().map(\.id)
        })
        return StatsSnapshot(period:period,readings:items,allReadings:all,books:items.count,pages:pages,readingDays:activity,
            averageRating:ratings.isEmpty ? nil : Double(ratings.reduce(0,+))/Double(ratings.count),ratedCount:ratings.count,
            noRatingCount:noRating,unknownRatingCount:items.count-ratings.count-noRating,
            genres:categories(items.map { $0.genre ?? "Unknown" }),formats:categories(items.map { $0.format?.rawValue.capitalized ?? "Unknown" }),
            time:timeline(period,completed,undated),undatedCompletions:undated,rereads:items.filter { rereadIDs.contains($0.id) }.count,
            selection:selection,candidates:candidates,selectionNeedsReview:invalid)
    }
    private static func timeline(_ period: StatsPeriod, _ completed: [StatsReading], _ undated: Int) -> [StatsTimePoint] {
        let dated = completed.filter { $0.finish != nil }
        func point(_ id: String, _ label: String, _ values: [StatsReading]) -> StatsTimePoint {
            .init(id:id,label:label,count:values.isEmpty && undated > 0 ? nil : values.count)
        }
        switch period {
        case let .month(y,m):
            var cal=Calendar(identifier:.gregorian); cal.timeZone=TimeZone(secondsFromGMT:0)!
            let date=cal.date(from:DateComponents(year:y,month:m,day:1))!
            return (1...cal.range(of:.day,in:.month,for:date)!.count).map { d in
                point("\(d)","\(d)",dated.filter { $0.finish?.year==y && $0.finish?.month==m && $0.finish?.day==d })
            }
        case let .year(y): return (1...12).map { m in point("\(m)",DateFormatter().shortMonthSymbols[m-1],dated.filter { $0.finish?.year==y && $0.finish?.month==m }) }
        case let .volume(y): return (y...min(9999,y+4)).map { n in point("\(n)","\(n)",dated.filter { $0.finish?.year==n }) }
        case .lifetime:
            let years=dated.compactMap { $0.finish?.year }
            guard let first=years.min(), let last=years.max() else { return [] }
            return (first...last).map { y in point("\(y)","\(y)",dated.filter { $0.finish?.year==y }) }
        }
    }
}
public protocol StatsRepository: Sendable {
    func stats(period: StatsPeriod) throws -> StatsSnapshot
    func selectBestBook(period: StatsPeriod, readingID: UUID?, expectedRevision: Int) throws
    /// Requires an explicitly supplied real reading date, never an operational timestamp inference.
    func recordReadingActivity(readingID: UUID, date: ReadingDate, sourceReference: String) throws
}
