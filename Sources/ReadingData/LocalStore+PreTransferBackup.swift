import Foundation
import GRDB

extension LocalStore {
    /// Creates a consistent SQLite backup using GRDB's backup API.
    /// This does not replace or mutate the active local database.
    /// The destination must not already exist, to avoid overwriting a previous backup.
    @discardableResult
    public func createPreTransferBackup(at destinationURL: URL) throws -> URL {
        let path = destinationURL.standardizedFileURL
        guard path.isFileURL, !FileManager.default.fileExists(atPath: path.path) else {
            throw BackupError.invalidDestination
        }
        let directory = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        // GRDB's backup() uses SQLite's online backup mechanism, including
        // committed WAL data, instead of copying a potentially incomplete .sqlite file.
        let destination = try DatabaseQueue(path: path.path)
        do {
            try queue.backup(to: destination)
        } catch {
            try? FileManager.default.removeItem(at: path)
            throw error
        }
        return path
    }

    public enum BackupError: Error {
        case invalidDestination
    }
}
