import Foundation
import Supabase
import ReadingDomain

/// Read-only inventory. An incomplete or changing inventory must never
/// authorize a first upload.
struct ReviewedCloudInventory {
    let client: SupabaseClient

    struct Summary: Sendable {
        let accountID: UUID
        let existingBooks: Int
        let existingReadings: Int
        let otherRecords: Int
        let recordIDs: Set<String>
    }

    enum InventoryError: Error {
        case accountChanged
        case tooManyRecords
        case duplicateRecord
    }

    func inspect() async throws -> Summary {
        let accountID = try await client.auth.session.user.id
        let transport = CloudReadingRecordTransport(client: client)
        var offset = 0
        let pageSize = 200
        var ids = Set<String>()
        var books = 0
        var readings = 0
        var others = 0
        while true {
            let page = try await transport.fetchPage(offset: offset, pageSize: pageSize)
            guard try await client.auth.session.user.id == accountID,
                  page.allSatisfy({ $0.ownerID == accountID }) else {
                throw InventoryError.accountChanged
            }
            for record in page {
                let key = "\(record.recordType.rawValue):\(record.recordID.uuidString)"
                guard ids.insert(key).inserted else { throw InventoryError.duplicateRecord }
                switch record.recordType {
                case .book: books += 1
                case .reading: readings += 1
                default: others += 1
                }
            }
            if page.count < pageSize { break }
            offset += pageSize
            guard offset < 100_000 else { throw InventoryError.tooManyRecords }
        }
        return Summary(accountID: accountID, existingBooks: books,
                       existingReadings: readings, otherRecords: others,
                       recordIDs: ids)
    }
}
