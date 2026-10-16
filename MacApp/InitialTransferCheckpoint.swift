import Foundation
import ReadingDomain

/// A durable checkpoint for an explicitly approved first upload.
/// Store this outside SQLite so it survives a failed app launch or partial upload.
struct InitialTransferCheckpoint: Codable, Equatable {
    let localOwnerID: UUID
    let cloudAccountID: UUID
    let approvedRecordIDs: [String]
    let payloadFingerprints: [String: String]
    let backupPath: String
    var successfulRevisions: [String: Int64]

    init(approval: InitialTransferApproval, backupURL: URL) {
        localOwnerID = approval.localOwnerID
        cloudAccountID = approval.cloudAccountID
        approvedRecordIDs = approval.approvedRecordIDs
        payloadFingerprints = approval.payloadFingerprints
        backupPath = backupURL.standardizedFileURL.path
        successfulRevisions = [:]
    }

    func matches(_ approval: InitialTransferApproval) -> Bool {
        localOwnerID == approval.localOwnerID &&
        cloudAccountID == approval.cloudAccountID &&
        approvedRecordIDs == approval.approvedRecordIDs &&
        payloadFingerprints == approval.payloadFingerprints
    }

    mutating func recordSuccess(id: String, revision: Int64) throws {
        guard approvedRecordIDs.contains(id), revision > 0 else {
            throw CheckpointError.invalidReceipt
        }
        successfulRevisions[id] = revision
    }

    enum CheckpointError: Error {
        case invalidReceipt, alreadyExists, invalidPath
    }

    /// Atomic replacement avoids a half-written checkpoint after a crash.
    func save(to url: URL, allowReplacement: Bool = false) throws {
        let destination = url.standardizedFileURL
        guard destination.isFileURL else { throw CheckpointError.invalidPath }
        if !allowReplacement && FileManager.default.fileExists(atPath: destination.path) {
            throw CheckpointError.alreadyExists
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(self).write(to: destination, options: .atomic)
    }

    static func load(from url: URL) throws -> Self {
        try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}
