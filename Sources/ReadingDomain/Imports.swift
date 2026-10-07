import Foundation

public enum ImportGroup: String, Codable, CaseIterable, Sendable {
    case newBooks = "New Books", updates = "Possible Updates", unchanged = "Already Up to Date", review = "Needs Review"
}
public enum ImportError: Error, Equatable, LocalizedError, Sendable {
    case invalidCSV, unsupportedHeaders, oversized, stalePreview, confirmationRequired, invalidResolution
    public var errorDescription: String? {
        switch self {
        case .invalidCSV: "The CSV is malformed or is not UTF-8. Nothing was imported."
        case .unsupportedHeaders: "This file does not contain StoryGraph Title, Authors and Read Status columns. Nothing was imported."
        case .oversized: "Use a CSV smaller than 10 MB with at most 10,000 rows. Nothing was imported."
        case .stalePreview: "Your library changed. Load the file again and review a fresh preview."
        case .confirmationRequired: "Confirm the preview before importing."
        case .invalidResolution: "Review the book identity and supplied reading information before applying."
        }
    }
}
/// Normalized, bounded facts only. External Format, reviews and unrelated CSV cells are never retained.
public struct StoryGraphRow: Codable, Equatable, Sendable {
    public let number: Int
    public let title: String
    public let author: String
    public let identity: String
    public let isbn: String?
    public let status: String
    public let starts: [ReadingDate?]
    public let finishes: [ReadingDate?]
    public let rating: Rating
    public let issues: [String]
}
public struct ImportCandidate: Codable, Identifiable, Sendable {
    public let id: UUID
    public let row: StoryGraphRow
    public let group: ImportGroup
    public let bookID: UUID?
    public let matches: [UUID]
    public let explanation: String
    public init(id: UUID, row: StoryGraphRow, group: ImportGroup, bookID: UUID?, matches: [UUID], explanation: String) {
        self.id=id; self.row=row; self.group=group; self.bookID=bookID; self.matches=matches; self.explanation=explanation
    }
}
public struct ImportPreview: Codable, Sendable {
    public let id: UUID
    public let fingerprint: String
    public let libraryFingerprint: String
    public let candidates: [ImportCandidate]
    public func count(_ group: ImportGroup) -> Int { candidates.filter { $0.group == group }.count }
    public init(id: UUID, fingerprint: String, libraryFingerprint: String, candidates: [ImportCandidate]) {
        self.id = id; self.fingerprint = fingerprint; self.libraryFingerprint = libraryFingerprint; self.candidates = candidates
    }
}
public struct ImportHistory: Codable, Identifiable, Sendable {
    public let id: UUID
    public let completedAt: String
    public let rows: Int
    public let newBooks: Int
    public let newReadings: Int
    public let review: Int
    public let unchanged: Int
    public init(id: UUID, completedAt: String, rows: Int, newBooks: Int, newReadings: Int, review: Int, unchanged: Int) {
        self.id=id; self.completedAt=completedAt; self.rows=rows; self.newBooks=newBooks; self.newReadings=newReadings; self.review=review; self.unchanged=unchanged
    }
}
public struct ImportReview: Identifiable, Sendable {
    public let id: UUID
    public let entityID: UUID
    public let field: String
    public let current: String
    public let proposed: String
    public let source: String
    public let userOverridden: Bool
    public init(id: UUID, entityID: UUID, field: String, current: String, proposed: String, source: String, userOverridden: Bool) {
        self.id=id; self.entityID=entityID; self.field=field; self.current=current; self.proposed=proposed; self.source=source; self.userOverridden=userOverridden
    }
}
public protocol ImportsRepository: Sendable {
    func previewStoryGraph(_ data: Data) throws -> ImportPreview
    func applyImport(_ preview: ImportPreview, confirmed: Bool) throws -> ImportHistory
    func importHistory() throws -> [ImportHistory]
    func importReviews() throws -> [ImportReview]
    func decideImport(id: UUID, accept: Bool) throws
    func pendingImportCandidates() throws -> [ImportCandidate]
    func resolveImportCandidate(id: UUID, bookID: UUID?, createSeparateBook: Bool, confirmed: Bool) throws
    func linkImportCandidate(id: UUID, bookID: UUID, readingIDs: [UUID], confirmed: Bool) throws
    func skipImportCandidate(id: UUID, confirmed: Bool) throws
}

/// RFC 4180 quoted fields, doubled quotes, CRLF and embedded line breaks. Never evaluates spreadsheet formulas.
public enum SafeCSV {
    public static func parse(_ data: Data) throws -> [[String]] {
        guard data.count <= 10_000_000 else { throw ImportError.oversized }
        guard var text = String(data: data, encoding: .utf8), !text.contains("\0") else { throw ImportError.invalidCSV }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let chars = Array(text); var index = 0; var quoted = false; var closed = false
        var field = ""; var row = [String](); var rows = [[String]](); var fieldLength = 0
        func appendRow() throws {
            row.append(field); field = ""; closed = false; fieldLength = 0
            if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
            row = []
            guard rows.count <= 10_001 else { throw ImportError.oversized }
        }
        while index < chars.count {
            let char = chars[index]
            if quoted {
                if char == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" { field.append("\""); index += 1 }
                    else { quoted = false; closed = true }
                } else { field.append(char) }
            } else if char == "," { row.append(field); field = ""; closed = false; fieldLength = 0 }
            else if char == "\n" { try appendRow() }
            else if char == "\"" { guard field.isEmpty && !closed else { throw ImportError.invalidCSV }; quoted = true }
            else { guard !closed else { throw ImportError.invalidCSV }; field.append(char) }
            fieldLength += 1
            guard fieldLength <= 100_000, row.count <= 200 else { throw ImportError.oversized }
            index += 1
        }
        guard !quoted else { throw ImportError.invalidCSV }
        if !field.isEmpty || !row.isEmpty || closed { try appendRow() }
        guard let header = rows.first, !header.isEmpty, rows.allSatisfy({ $0.count == header.count }) else { throw ImportError.invalidCSV }
        return rows
    }
}

public enum StoryGraphAdapter {
    public static func rows(_ data: Data) throws -> [StoryGraphRow] {
        let csv = try SafeCSV.parse(data)
        let headers = csv[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard Set(headers).count == headers.count, ["title", "authors", "read status"].allSatisfy(headers.contains) else { throw ImportError.unsupportedHeaders }
        return try csv.dropFirst().enumerated().map { offset, cells in
            func cell(_ name: String) -> String { headers.firstIndex(of: name).map { cells[$0].trimmingCharacters(in: .whitespacesAndNewlines) } ?? "" }
            var issues = [String]()
            let title = cell("title"), author = cell("authors"), rawID = cell("isbn/uid")
            if title.isEmpty || author.isEmpty { issues.append("Title or author is missing. Correct the source or add the book manually.") }
            let isbnValue = rawID.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
            let isbn: String? = validISBN(isbnValue) ? isbnValue : nil
            let identity = !rawID.isEmpty ? "uid:" + rawID : "text:" + title + "\u{1F}" + author
            let status = cell("read status").lowercased()
            if !["read", "to-read", "currently-reading", "did-not-finish"].contains(status) { issues.append("This reading status is unsupported. No reading will be inferred.") }
            let rawCount = cell("read count")
            let count = rawCount.isEmpty ? (status == "read" ? 1 : 0) : Int(rawCount)
            guard let count, (0...1000).contains(count) else { throw ImportError.invalidCSV }
            if status == "read" && count == 0 { issues.append("Read status conflicts with a zero read count.") }
            var starts = [ReadingDate?](), finishes = [ReadingDate?]()
            let ranges = cell("dates read")
            if !ranges.isEmpty {
                for range in ranges.components(separatedBy: ",") {
                    let pair = range.trimmingCharacters(in: .whitespaces).components(separatedBy: "-")
                    if pair.count == 2 {
                        starts.append(parseDate(pair[0], issues: &issues)); finishes.append(parseDate(pair[1], issues: &issues))
                    } else { issues.append("Reading date ranges are not recognized. No dates were inferred.") }
                }
            }
            if starts.isEmpty && count > 0 {
                starts = Array(repeating: nil, count: count); finishes = Array(repeating: nil, count: count)
                // Day-first Last Date Read is intentionally not guessed. Only unambiguous year-first values are accepted.
                finishes[count - 1] = parseDate(cell("last date read"), issues: &issues)
            }
            if !ranges.isEmpty && starts.count != count { issues.append("Read count and dated occurrences disagree. Review the source; no occurrences will be invented.") }
            for (start, finish) in zip(starts, finishes) { if let start, let finish, start > finish { issues.append("Start date follows finish date.") } }
            var rating = Rating.unknown
            let ratingText = cell("star rating")
            if !ratingText.isEmpty {
                if ratingText == "0" { rating = .noRating }
                else if let value = Double(ratingText), value.isFinite, value.rounded() == value, (1...5).contains(value) { rating = try .validatedStars(Int(value)) }
                else { issues.append("The imported rating is not a whole star from 1 to 5. It has not been rounded; choose a rating manually.") }
            }
            return StoryGraphRow(number: offset + 2, title: title, author: author, identity: identity, isbn: isbn, status: status, starts: starts, finishes: finishes, rating: rating, issues: Array(Set(issues)).sorted())
        }
    }
    private static func parseDate(_ text: String, issues: inout [String]) -> ReadingDate? {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        let parts = text.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]), let date = try? ReadingDate(year: year, month: month, day: day) else { issues.append("A date is ambiguous or invalid. Correct it to YYYY/MM/DD; no date was inferred."); return nil }
        return date
    }
    public static func validISBN(_ value: String) -> Bool {
        let chars = Array(value.uppercased())
        let digits = chars.compactMap { $0.wholeNumberValue }
        if chars.count == 13, digits.count == 13 {
            return digits.enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 1 : 3) }.isMultiple(of: 10)
        }
        if chars.count == 10 {
            let digits = chars.enumerated().compactMap { index, char in char == "X" && index == 9 ? 10 : char.wholeNumberValue }
            return digits.count == 10 && digits.enumerated().reduce(0) { $0 + $1.element * (10 - $1.offset) }.isMultiple(of: 11)
        }
        return false
    }
}
