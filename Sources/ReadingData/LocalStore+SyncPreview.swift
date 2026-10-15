import Foundation
import ReadingDomain

extension LocalStore {
    /// Snapshot of the current owner's local books and readings; no writes.
    /// A cloud upload requires a separate account and remote inventory review.
    public func coreSyncPreview(remoteRecordIDs: Set<String> = []) throws -> CoreSyncUploadPreview.Plan {
        try queue.read { db in
            let snapshot = try CoreSyncSQLiteExport.snapshot(
                from: db, ownerID: ownerID.uuidString)
            return try CoreSyncUploadPreview.make(
                books: snapshot.books,
                readings: snapshot.readings,
                remoteRecordIDs: remoteRecordIDs)
        }
    }
}
