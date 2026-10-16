import Foundation
import ReadingDomain
import ReadingData
import Supabase

/// Read-only assessment of a previously interrupted first upload.
/// It never performs cloud writes or changes the local database.
struct ReviewedTransferRecoveryInspector {
    let client: SupabaseClient

    enum InspectionError: Error {
        case accountChanged
        case localDataChanged
        case backupMissing
        case incompleteInventory
        case duplicateRemoteRecord
    }

    func inspect(store: LocalStore,
                 approval: InitialTransferApproval,
                 checkpointURL: URL) async throws -> InitialTransferRecovery.Result {
        let checkpoint = try InitialTransferCheckpoint.load(from: checkpointURL)
        guard checkpoint.matches(approval),
              try await client.auth.session.user.id == approval.cloudAccountID else {
            throw InspectionError.accountChanged
        }
        guard FileManager.default.fileExists(atPath: checkpoint.backupPath) else {
            throw InspectionError.backupMissing
        }
        let plan = try store.coreSyncPreview()
        guard plan.canUpload,
              approval.matches(localOwnerID: store.ownerID,
                               cloudAccountID: approval.cloudAccountID,
                               records: plan.items) else {
            throw InspectionError.localDataChanged
        }
        let approved = Dictionary(uniqueKeysWithValues: plan.items.map {
            ("\($0.recordType.rawValue):\($0.recordID.uuidString)", $0.payload)
        })
        var remote: [String: InitialTransferRecovery.VerifiedRemoteRecord] = [:]
        let transport = CloudReadingRecordTransport(client: client)
        var offset = 0
        while true {
            let page = try await transport.fetchPage(offset: offset, pageSize: 200)
            for row in page {
                let id = "\(row.recordType.rawValue):\(row.recordID.uuidString)"
                guard remote[id] == nil else { throw InspectionError.duplicateRemoteRecord }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let bytes = try encoder.encode(row.payload)
                remote[id] = .init(ownerID: row.ownerID, revision: row.revision,
                                   payload: bytes, isDeleted: row.isDeleted)
            }
            if page.count < 200 { break }
            offset += page.count
            guard offset < 100_000 else { throw InspectionError.incompleteInventory }
        }
        guard try await client.auth.session.user.id == approval.cloudAccountID else {
            throw InspectionError.accountChanged
        }
        // Conservative: differences in JSON encoding also count as conflicts.
        // Never infer success solely from an equal revision number.
        return InitialTransferRecovery.reconcileVerified(
            cloudAccountID: approval.cloudAccountID,
            approvedPayloads: approved,
            successfulRevisions: checkpoint.successfulRevisions,
            remoteRecords: remote)
    }
}
