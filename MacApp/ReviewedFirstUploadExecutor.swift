import Foundation
import ReadingDomain
import ReadingData
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
        case localSnapshotChanged
    }

    /// An approved transfer must re-read SQLite immediately before sending.
    /// A backup is mandatory and the authorization is tied to both identities.
    /// The caller must retain the approval and backup for recovery.
    func uploadApproved(store: LocalStore,
                        approval: InitialTransferApproval,
                        approvedItems: [CoreSyncUploadPreview.Item],
                        backupURL: URL,
                        confirmed: Bool) async throws -> [String: Int64] {
        guard confirmed else { throw UploadError.confirmationRequired }
        let currentAccount = try await client.auth.session.user.id
        guard currentAccount == approval.cloudAccountID else {
            throw UploadError.accountChanged
        }
        let latest = try store.coreSyncPreview()
        guard latest.canUpload,
              approval.matches(localOwnerID: store.ownerID,
                               cloudAccountID: currentAccount,
                               records: latest.items),
              latest.items == approvedItems else {
            throw UploadError.localSnapshotChanged
        }
        // The SQLite backup is created only after the fresh snapshot passes.
        // If backup fails, upload never starts.
        try store.createPreTransferBackup(at: backupURL)
        let checkpointURL = backupURL.deletingPathExtension()
            .appendingPathExtension("checkpoint.json")
        let checkpoint = InitialTransferCheckpoint(approval: approval, backupURL: backupURL)
        // Persist the initial checkpoint before the first cloud write.
        try checkpoint.save(to: checkpointURL)
        return try await upload(plan: latest, confirmed: confirmed,
                                expectedAccountID: currentAccount,
                                approvedRecordIDs: Set(approval.approvedRecordIDs),
                                approvedItems: approvedItems,
                                checkpointURL: checkpointURL,
                                checkpoint: checkpoint)
    }

    /// Uses a complete, paginated remote inventory and refuses any preexisting
    /// cloud record for this account. No SQLite writes occur.
    func upload(plan: CoreSyncUploadPreview.Plan,
                confirmed: Bool,
                expectedAccountID: UUID,
                approvedRecordIDs: Set<String>,
                approvedItems: [CoreSyncUploadPreview.Item],
                checkpointURL: URL,
                checkpoint: InitialTransferCheckpoint) async throws -> [String: Int64] {
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
        var receipt = checkpoint
        for item in plan.items {
            guard try await client.auth.session.user.id == expectedAccountID else {
                throw UploadError.accountChanged
            }
            let document = try JSONDecoder().decode(JSONDocument.self, from: item.payload)
            let revision = try await writer.save(
                recordType: item.recordType, recordID: item.recordID,
                payload: document, expectedRevision: 0, isDeleted: item.isDeleted)
            let id = "\(item.recordType.rawValue):\(item.recordID.uuidString)"
            revisions[id] = revision
            try receipt.recordSuccess(id: id, revision: revision)
            try receipt.save(to: checkpointURL, allowReplacement: true)
        }
        return revisions
    }
}
