import Foundation
import Supabase
import ReadingDomain

/// Explicit cloud writes only: this service never modifies local SQLite.
/// A caller must review the migration and supply its last known remote revision.
struct ReviewedCloudWriter {
    let client: SupabaseClient

    struct SaveRequest: Encodable {
        let p_record_type: String
        let p_record_id: UUID
        let p_payload: [String: String]
        let p_expected_revision: Int64
        let p_is_deleted: Bool
    }

    enum WriteError: Error {
        case accountNotAuthenticated
        case invalidPayload
        case invalidExpectedRevision
    }

    /// First creation uses expectedRevision 0; subsequent updates must use
    /// the server-confirmed revision. Conflicts are surfaced to the caller.
    func save(recordType: CloudReadingRecord.RecordType,
              recordID: UUID,
              payload: [String: String],
              expectedRevision: Int64,
              isDeleted: Bool = false) async throws -> Int64 {
        guard expectedRevision >= 0 else { throw WriteError.invalidExpectedRevision }
        _ = try await client.auth.session
        let request = SaveRequest(p_record_type: recordType.rawValue,
                                  p_record_id: recordID,
                                  p_payload: payload,
                                  p_expected_revision: expectedRevision,
                                  p_is_deleted: isDeleted)
        let revision: Int64 = try await client.database
            .rpc("save_reading_record", params: request)
            .execute()
            .value
        return revision
    }
}
