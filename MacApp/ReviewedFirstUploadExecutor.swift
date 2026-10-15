import Foundation
import ReadingDomain
import Supabase

/// A deliberately explicit first-upload operation, never invoked at launch.
/// Caller must display the complete preview and obtain confirmation.
struct ReviewedFirstUploadExecutor {
    let client: SupabaseClient

    enum UploadError: Error {
        case confirmationRequired
        case pendingReview
        case accountChanged
        case remoteRecordsExist
        case incompleteRemoteInventory
        case approvalMismatch
    }

    /// Uses a complete, paginated remote inventory and refuses any preexisting
    /// cloud record for this account. No SQLite writes occur.
    func upload(plan: CoreSyncUploadPreview.Plan,
                confirmed: Bool,
                expectedAccountID: UUID,
                approvedRecordIDs: Set<String>,
                approvedItems: [CoreSyncUploadPreview.Item]) async throws -> [String: Int64] {
        guard confirmed else { throw UploadError.confirmationRequired }
        guard plan.canUpload else { throw UploadError.pendingReview }
        let plannedIDs = Set(plan.items.map { "\($0.recordType.rawValue):\($0.recordID.uuidString)" })
        guard plannedIDs == approvedRecordIDs, plan.items == approvedItems else {
            throw UploadError.approvalMismatch
        }
        let transport = CloudReadingRecordTransport(client: client)
        let pageSize = 200
        var offset = 0
        while true {
            let page = try await transport.fetchPage(offset: offset, pageSize: pageSize)
            guard page.allSatisfy({ $0.ownerID == expectedAccountID }) else {
                throw UploadError.accountChanged
            }
            guard page.isEmpty else { throw UploadError.remoteRecordsExist }
            if page.count < pageSize { break }
            offset += pageSize
            guard offset < 100_000 else { throw UploadError.incompleteRemoteInventory }
        }
        guard try await client.auth.session.user.id == expectedAccountID else {
            throw UploadError.accountChanged
        }

        let writer = ReviewedCloudWriter(client: client)
        var revisions: [String: Int64] = [:]
        for item in plan.items {
            guard try await client.auth.session.user.id == expectedAccountID else {
                throw UploadError.accountChanged
            }
            let document = try JSONDecoder().decode(JSONDocument.self, from: item.payload)
            let revision = try await writer.save(
                recordType: item.recordType, recordID: item.recordID,
                payload: document, expectedRevision: 0, isDeleted: item.isDeleted)
            revisions["\(item.recordType.rawValue):\(item.recordID.uuidString)"] = revision
        }
        return revisions
    }
}
