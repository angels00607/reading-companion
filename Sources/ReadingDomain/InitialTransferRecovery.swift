import Foundation

/// Pure, conservative reconciliation of a partially completed first upload.
/// No network or SQLite writes. Never assumes a matching identifier has matching data.
public enum InitialTransferRecovery {
    public struct Result: Equatable, Sendable {
        public let completedIDs: [String]
        public let remainingIDs: [String]
        public let conflictingIDs: [String]
        public var canResume: Bool { conflictingIDs.isEmpty }
    }

    /// Stronger recovery validation: a matching revision is not sufficient.
    /// Compare each acknowledged record's canonical JSON bytes to the approved
    /// upload bytes; unknown, missing or altered remote payloads block resumption.
    /// The caller must verify the remote owner and deletion flag before using this.
    public static func reconcileVerified(
        approvedPayloads: [String: Data],
        successfulRevisions: [String: Int64],
        remoteRecords: [String: (revision: Int64, payload: Data)]
    ) -> Result {
        let baseline = reconcile(
            approvedRecordIDs: Array(approvedPayloads.keys),
            successfulRevisions: successfulRevisions,
            remoteRevisions: remoteRecords.mapValues { $0.revision })
        var conflicts = Set(baseline.conflictingIDs)
        for id in baseline.completedIDs {
            guard let approved = approvedPayloads[id],
                  let remote = remoteRecords[id],
                  approved == remote.payload else {
                conflicts.insert(id)
                continue
            }
        }
        return Result(
            completedIDs: baseline.completedIDs.filter { !conflicts.contains($0) },
            remainingIDs: baseline.remainingIDs,
            conflictingIDs: conflicts.sorted())
    }

    /// Complete recovery comparison including the account owner and deletion state.
    /// The approved payloads must be the same exact bytes reviewed by the user.
    public struct VerifiedRemoteRecord: Sendable {
        public let ownerID: UUID
        public let revision: Int64
        public let payload: Data
        public let isDeleted: Bool

        public init(ownerID: UUID, revision: Int64, payload: Data, isDeleted: Bool) {
            self.ownerID = ownerID
            self.revision = revision
            self.payload = payload
            self.isDeleted = isDeleted
        }
    }

    public static func reconcileVerified(
        cloudAccountID: UUID,
        approvedPayloads: [String: Data],
        successfulRevisions: [String: Int64],
        remoteRecords: [String: VerifiedRemoteRecord]
    ) -> Result {
        let baseline = reconcile(
            approvedRecordIDs: Array(approvedPayloads.keys),
            successfulRevisions: successfulRevisions,
            remoteRevisions: remoteRecords.mapValues { $0.revision })
        var conflicts = Set(baseline.conflictingIDs)
        for id in baseline.completedIDs {
            guard let approved = approvedPayloads[id],
                  let remote = remoteRecords[id],
                  remote.ownerID == cloudAccountID,
                  !remote.isDeleted,
                  remote.payload == approved else {
                conflicts.insert(id)
                continue
            }
        }
        // Unexpected remote records remain conflicts even if their payload matches.
        return Result(completedIDs: baseline.completedIDs.filter { !conflicts.contains($0) },
                      remainingIDs: baseline.remainingIDs,
                      conflictingIDs: conflicts.sorted())
    }

    /// A successful write receipt is valid only when its cloud revision still
    /// matches the remote inventory. Unrecognized cloud records block resumption.
    public static func reconcile(
        approvedRecordIDs: [String],
        successfulRevisions: [String: Int64],
        remoteRevisions: [String: Int64]
    ) -> Result {
        let approved = Set(approvedRecordIDs)
        var completed: [String] = []
        var remaining: [String] = []
        var conflicts = Set(remoteRevisions.keys).subtracting(approved)
        for id in approved.sorted() {
            let receipt = successfulRevisions[id]
            let remote = remoteRevisions[id]
            switch (receipt, remote) {
            case (nil, nil):
                remaining.append(id)
            case (.some(let expected), .some(let actual)) where expected > 0 && expected == actual:
                completed.append(id)
            default:
                conflicts.insert(id)
            }
        }
        // A receipt for an unapproved item cannot authorize its deletion or overwrite.
        conflicts.formUnion(Set(successfulRevisions.keys).subtracting(approved))
        return Result(completedIDs: completed, remainingIDs: remaining,
                      conflictingIDs: conflicts.sorted())
    }
}
