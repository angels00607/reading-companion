import Foundation
import Supabase
import ReadingDomain

/// Read-only transport. Deliberately does not write to Supabase or local SQLite.
/// Callers must first verify the account and plan a reviewed migration.
struct CloudReadingRecordTransport {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    struct RemoteRow: Decodable, Sendable {
        let ownerID: UUID
        let recordType: CloudReadingRecord.RecordType
        let recordID: UUID
        let payload: [String: JSONValue]
        let revision: Int64
        let isDeleted: Bool

        enum CodingKeys: String, CodingKey {
            case ownerID = "owner_id"
            case recordType = "record_type"
            case recordID = "record_id"
            case payload, revision
            case isDeleted = "is_deleted"
        }
    }

    /// A bounded page avoids silently truncating larger libraries.
    func fetchPage(offset: Int, pageSize: Int = 200) async throws -> [RemoteRow] {
        guard offset >= 0, (1...500).contains(pageSize) else {
            throw TransportError.invalidPagination
        }
        let session = try await client.auth.session
        let response: [RemoteRow] = try await client.from("reading_records")
            .select("owner_id,record_type,record_id,payload,revision,is_deleted")
            .eq("owner_id", value: session.user.id.uuidString)
            .order("record_type", ascending: true)
            .order("record_id", ascending: true)
            .range(from: offset, to: offset + pageSize - 1)
            .execute()
            .value
        guard response.allSatisfy({ $0.ownerID == session.user.id }) else {
            throw TransportError.accountMismatch
        }
        return response
    }

    enum TransportError: Error {
        case invalidPagination
        case accountMismatch
    }
}
