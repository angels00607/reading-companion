import Foundation

/// An explicit, non-mutating preview of the first cloud upload.
/// No caller should upload if any item needs review.
public enum CoreSyncUploadPreview {
    public struct Item: Equatable, Sendable {
        public let recordType: CloudReadingRecord.RecordType
        public let recordID: UUID
        public let payload: Data
        public let isDeleted: Bool
    }

    public struct Plan: Sendable {
        public let items: [Item]
        public let needsReview: [String]
        public var canUpload: Bool { needsReview.isEmpty }
    }

    /// Exports book and reading records only. Other local tables remain outside
    /// the plan and must not be treated as synced or deleted.
    public static func make(
        books: [UUID: CoreSyncPayloads.Book],
        readings: [UUID: CoreSyncPayloads.Reading],
        remoteRecordIDs: Set<String>
    ) throws -> Plan {
        var items: [Item] = []
        var needsReview: [String] = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        for (id, book) in books.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            let key = "book:\(id.uuidString)"
            if remoteRecordIDs.contains(key) {
                needsReview.append("Existing remote book requires a three-way comparison: \(id)")
                continue
            }
            if book.deletedAt != nil {
                needsReview.append("Unconfirmed local book deletion: \(id)")
                continue
            }
            items.append(Item(recordType: .book, recordID: id,
                              payload: try encoder.encode(book), isDeleted: false))
        }
        for (id, reading) in readings.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            let key = "reading:\(id.uuidString)"
            if remoteRecordIDs.contains(key) {
                needsReview.append("Existing remote reading requires a three-way comparison: \(id)")
                continue
            }
            if reading.deletedAt != nil {
                needsReview.append("Unconfirmed local reading deletion: \(id)")
                continue
            }
            if books[reading.bookID] == nil || books[reading.bookID]?.deletedAt != nil {
                needsReview.append("Reading references a missing local book: \(id)")
                continue
            }
            items.append(Item(recordType: .reading, recordID: id,
                              payload: try encoder.encode(reading), isDeleted: false))
        }
        // An incomplete export must never be mistaken for a complete library.
        return Plan(items: items, needsReview: needsReview)
    }
}
