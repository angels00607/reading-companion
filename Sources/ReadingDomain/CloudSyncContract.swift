import Foundation

/// A platform-independent, opt-in synchronization contract.
/// Nothing in this module uploads data or changes the local SQLite owner.
public struct CloudReadingRecord: Codable, Equatable, Sendable, Identifiable {
    public let ownerID: UUID
    public let recordType: RecordType
    public let recordID: UUID
    public let payload: Data
    public let revision: Int64
    public let isDeleted: Bool

    public var id: String { "\(recordType.rawValue):\(recordID.uuidString)" }

    public init(ownerID: UUID, recordType: RecordType, recordID: UUID,
                payload: Data, revision: Int64, isDeleted: Bool = false) throws {
        guard revision > 0 else { throw SyncValidationError.invalidRevision }
        guard (try? JSONSerialization.jsonObject(with: payload)) is [String: Any] else {
            throw SyncValidationError.payloadMustBeObject
        }
        self.ownerID = ownerID
        self.recordType = recordType
        self.recordID = recordID
        self.payload = payload
        self.revision = revision
        self.isDeleted = isDeleted
    }

    public enum RecordType: String, Codable, Sendable {
        case book, reading, series, review, quote, favorite, challenge, settings, statistics
    }
}

public enum SyncValidationError: Error, Equatable, Sendable {
    case invalidRevision
    case payloadMustBeObject
}

public enum SyncDecision: Equatable, Sendable {
    case uploadLocal
    case downloadRemote
    case unchanged
    case needsUserReview
}

/// The caller must supply a last-confirmed common ancestor (base).
/// If none exists, never guess which copy is authoritative.
public enum ReadingSyncPlanner {
    public static func decide(local: CloudReadingRecord?,
                              remote: CloudReadingRecord?,
                              base: CloudReadingRecord?) -> SyncDecision {
        if local == remote { return .unchanged }
        guard let base else {
            if local == nil && remote == nil { return .unchanged }
            if local != nil && remote == nil { return .uploadLocal }
            if local == nil && remote != nil { return .downloadRemote }
            return .needsUserReview
        }
        let localChanged = local != base
        let remoteChanged = remote != base
        switch (localChanged, remoteChanged) {
        case (false, false): return .unchanged
        case (true, false): return .uploadLocal
        case (false, true): return .downloadRemote
        case (true, true): return .needsUserReview
        }
    }
}

/// A deletion is a tombstone, not a missing row. Tombstones must be
/// acknowledged on both devices before any future compaction.
public struct SyncCheckpoint: Codable, Equatable, Sendable {
    public let ownerID: UUID
    public let recordType: CloudReadingRecord.RecordType
    public let recordID: UUID
    public let lastConfirmedRevision: Int64
    public init(ownerID: UUID, recordType: CloudReadingRecord.RecordType,
                recordID: UUID, lastConfirmedRevision: Int64) throws {
        guard lastConfirmedRevision > 0 else { throw SyncValidationError.invalidRevision }
        self.ownerID = ownerID
        self.recordType = recordType
        self.recordID = recordID
        self.lastConfirmedRevision = lastConfirmedRevision
    }
}
