import Foundation

/// Conservative first-contact comparison, without a common synchronization
/// ancestor. Never assumes that a remote-only record should be downloaded or
/// that two records sharing an ID have identical contents.
public enum FirstSyncInventoryComparison {
    public struct Result: Equatable, Sendable {
        public let newLocalIDs: [String]
        public let remoteOnlyIDs: [String]
        public let overlappingIDs: [String]
        public let localDeletionIDs: [String]
        public let remoteDeletionIDs: [String]

        public var requiresReview: Bool {
            !remoteOnlyIDs.isEmpty || !overlappingIDs.isEmpty ||
            !localDeletionIDs.isEmpty || !remoteDeletionIDs.isEmpty
        }
    }

    public static func compare(local: CoreSyncUploadPreview.Plan,
                               remote: [CloudReadingRecord]) -> Result {
        let localKeys = Set(local.items.map { "\($0.recordType.rawValue):\($0.recordID.uuidString)" })
        let remoteKeys = Set(remote.map(\.id))
        let localDeleted = Set(local.items.filter(\.isDeleted).map {
            "\($0.recordType.rawValue):\($0.recordID.uuidString)"
        })
        let remoteDeleted = Set(remote.filter(\.isDeleted).map(\.id))
        return Result(
            newLocalIDs: (localKeys.subtracting(remoteKeys).subtracting(localDeleted)).sorted(),
            remoteOnlyIDs: remoteKeys.subtracting(localKeys).sorted(),
            overlappingIDs: localKeys.intersection(remoteKeys).sorted(),
            localDeletionIDs: localDeleted.sorted(),
            remoteDeletionIDs: remoteDeleted.sorted()
        )
    }
}
