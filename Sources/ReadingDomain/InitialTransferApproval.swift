import Foundation

/// Persistable, explicit authorization for a single reviewed initial transfer.
/// Does not grant authorization to mutate SQLite or overwrite remote records.
public struct InitialTransferApproval: Codable, Equatable, Sendable {
    public let localOwnerID: UUID
    public let cloudAccountID: UUID
    public let approvedAt: Date
    public let approvedRecordIDs: [String]
    public let payloadFingerprints: [String: String]

    public enum ApprovalError: Error {
        case noRecords, duplicateRecord, missingFingerprint, invalidFingerprint
    }

    public init(localOwnerID: UUID, cloudAccountID: UUID, approvedAt: Date,
                records: [CoreSyncUploadPreview.Item]) throws {
        guard !records.isEmpty else { throw ApprovalError.noRecords }
        let ids = records.map { "\($0.recordType.rawValue):\($0.recordID.uuidString)" }
        guard Set(ids).count == ids.count else { throw ApprovalError.duplicateRecord }
        var fingerprints: [String: String] = [:]
        for (id, record) in zip(ids, records) {
            // Stable exact-byte digest, independent of Swift's randomized Hasher.
            fingerprints[id] = Self.hexDigest(record.payload)
        }
        self.localOwnerID = localOwnerID
        self.cloudAccountID = cloudAccountID
        self.approvedAt = approvedAt
        self.approvedRecordIDs = ids.sorted()
        self.payloadFingerprints = fingerprints
    }

    public func matches(localOwnerID: UUID, cloudAccountID: UUID,
                        records: [CoreSyncUploadPreview.Item]) -> Bool {
        guard self.localOwnerID == localOwnerID,
              self.cloudAccountID == cloudAccountID else { return false }
        let ids = records.map { "\($0.recordType.rawValue):\($0.recordID.uuidString)" }
        guard ids.sorted() == approvedRecordIDs else { return false }
        return zip(ids, records).allSatisfy { id, record in
            payloadFingerprints[id] == Self.hexDigest(record.payload)
        }
    }

    // FNV-1a is a deterministic change detector, NOT a cryptographic signature.
    // Exact payload equality must still be verified at execution time.
    private static func hexDigest(_ data: Data) -> String {
        var value: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            value = (value ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return String(value, radix: 16)
    }
}
