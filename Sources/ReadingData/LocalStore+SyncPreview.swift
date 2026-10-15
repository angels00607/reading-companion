import Foundation
import ReadingDomain

extension LocalStore {
    /// Snapshot of the current owner's local books and readings; no writes.
    public func coreSyncPreview() throws -> CoreSyncUploadPreview.Plan {
        try queue.read { db in
            let snapshot = try CoreSyncSQLiteExport.snapshot(
                from: db, ownerID: ownerID.uuidString)
            // This is only a LOCAL preview. It cannot authorize a cloud upload:
            // the authenticated account and complete remote inventory are unknown.
            return try CoreSyncUploadPreview.make(
                books: snapshot.books,
                readings: snapshot.readings,
                remoteRecordIDs: [])
        }
    }
}
