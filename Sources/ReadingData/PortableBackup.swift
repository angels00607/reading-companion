import Foundation
import CoreFoundation
import CryptoKit
import ZIPFoundation

/// Logical interchange versions, deliberately independent of GRDB migration numbers.
public struct BackupManifest: Codable, Equatable, Sendable {
    public let backupFormatVersion: Int
    public let schemaVersion: Int
    public let appVersion: String
    public let createdAt: String
    /// Coarse platform description only; never a hardware ID, account name or device name.
    public let sourceDevice: String
    public let entityCounts: [String: Int]
    public let checksumAlgorithm: String
    public let files: [BackupFileMetadata]
}

public struct BackupFileMetadata: Codable, Equatable, Sendable {
    public let path: String
    public let byteCount: Int
    public let sha256: String
}

/// Integrity validation is not restore approval or proof of trustworthy domain facts.
/// There is intentionally no persistence operation in this archive boundary.
public struct ValidatedPortableBackup: Sendable {
    public let manifest: BackupManifest
    public let json: Data
    public let assets: [String: Data]
}

public enum PortableBackupError: Error, Equatable {
    case invalidArchive, unsupportedVersion, invalidManifest, invalidPayload
    case unsafeEntry, duplicateEntry, inventoryMismatch, integrityMismatch
    case resourceLimit, credentialMaterial
}

public struct PortableBackupLimits: Sendable {
    public var archiveBytes: Int = 128 * 1024 * 1024
    public var expandedBytes: Int = 128 * 1024 * 1024
    public var entryBytes: Int = 64 * 1024 * 1024
    public var manifestBytes: Int = 1024 * 1024
    public var entries: Int = 10_000
    public init() {}
}

/// Versioned ZIP + JSON packaging. Domain snapshot/export and transactional restore
/// must validate their own typed relationships, ownership and permanent XP separately.
public struct PortableBackupCodec: Sendable {
    public static let formatVersion = 1
    public static let schemaVersion = 1
    public let limits: PortableBackupLimits
    public init(limits: PortableBackupLimits = .init()) { self.limits = limits }

    public func encode(json: Data, assets: [String: Data] = [:], appVersion: String,
                       createdAt: Date, sourceDevice: String = "iOS") throws -> Data {
        let counts = try payloadCounts(json)
        var contents = assets
        for path in assets.keys { guard Self.isAssetPath(path) else { throw PortableBackupError.unsafeEntry } }
        contents["data.json"] = json
        let metadata = contents.keys.sorted().map { path in
            BackupFileMetadata(path: path, byteCount: contents[path]!.count, sha256: Self.digest(contents[path]!))
        }
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let manifest = BackupManifest(backupFormatVersion: Self.formatVersion, schemaVersion: Self.schemaVersion,
            appVersion: appVersion, createdAt: dateFormatter.string(from: createdAt), sourceDevice: sourceDevice,
            entityCounts: counts, checksumAlgorithm: "SHA-256", files: metadata)
        try validateManifest(manifest)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        contents["manifest.json"] = try encoder.encode(manifest)
        try checkSizes(contents)
        let archive = try Archive(accessMode: .create)
        for path in contents.keys.sorted() {
            let bytes = contents[path]!
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(bytes.count),
                                 modificationDate: createdAt, compressionMethod: .deflate) { position, size in
                let start = Int(position)
                return bytes.subdata(in: start..<min(start + size, bytes.count))
            }
        }
        guard let result = archive.data, result.count <= limits.archiveBytes else { throw PortableBackupError.resourceLimit }
        // Export and restore share the exact same integrity gate.
        _ = try decode(result)
        return result
    }

    public func decode(_ bytes: Data) throws -> ValidatedPortableBackup {
        guard bytes.count <= limits.archiveBytes else { throw PortableBackupError.resourceLimit }
        let advertisedCount = try zipEntryCount(bytes)
        guard advertisedCount <= limits.entries else { throw PortableBackupError.resourceLimit }
        let archive: Archive
        do { archive = try Archive(data: bytes, accessMode: .read) }
        catch { throw PortableBackupError.invalidArchive }
        var entries: [String: Entry] = [:]
        var total: UInt64 = 0
        for entry in archive {
            guard entry.type == .file, Self.isAllowedPath(entry.path) else { throw PortableBackupError.unsafeEntry }
            guard entries[entry.path] == nil else { throw PortableBackupError.duplicateEntry }
            guard entries.count < limits.entries, entry.uncompressedSize <= UInt64(max(0, limits.entryBytes)) else {
                throw PortableBackupError.resourceLimit
            }
            total += entry.uncompressedSize
            guard total <= UInt64(max(0, limits.expandedBytes)) else { throw PortableBackupError.resourceLimit }
            entries[entry.path] = entry
        }
        guard entries.count == advertisedCount, let manifestEntry = entries["manifest.json"] else {
            throw PortableBackupError.invalidArchive
        }
        guard manifestEntry.uncompressedSize <= UInt64(max(0, limits.manifestBytes)) else { throw PortableBackupError.resourceLimit }
        let manifestData = try read(manifestEntry, archive: archive, maximum: limits.manifestBytes)
        let manifest: BackupManifest
        do { manifest = try JSONDecoder().decode(BackupManifest.self, from: manifestData) }
        catch { throw PortableBackupError.invalidManifest }
        try validateManifest(manifest)
        let expected = Set(manifest.files.map(\.path)).union(["manifest.json"])
        guard Set(entries.keys) == expected else { throw PortableBackupError.inventoryMismatch }
        var contents: [String: Data] = [:]
        for file in manifest.files {
            guard let entry = entries[file.path], entry.uncompressedSize == UInt64(file.byteCount) else {
                throw PortableBackupError.integrityMismatch
            }
            let data = try read(entry, archive: archive, maximum: file.byteCount)
            guard data.count == file.byteCount, Self.digest(data) == file.sha256 else { throw PortableBackupError.integrityMismatch }
            contents[file.path] = data
        }
        guard let json = contents.removeValue(forKey: "data.json"), try payloadCounts(json) == manifest.entityCounts else {
            throw PortableBackupError.invalidPayload
        }
        return ValidatedPortableBackup(manifest: manifest, json: json, assets: contents)
    }

    private func read(_ entry: Entry, archive: Archive, maximum: Int) throws -> Data {
        var result = Data()
        do {
            let crc = try archive.extract(entry) { chunk in
                guard chunk.count <= maximum - result.count else { throw PortableBackupError.resourceLimit }
                result.append(chunk)
            }
            guard crc == entry.checksum else { throw PortableBackupError.integrityMismatch }
        } catch let error as PortableBackupError { throw error }
        catch { throw PortableBackupError.invalidArchive }
        return result
    }

    private func validateManifest(_ manifest: BackupManifest) throws {
        guard manifest.backupFormatVersion == Self.formatVersion, manifest.schemaVersion == Self.schemaVersion else {
            throw PortableBackupError.unsupportedVersion
        }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard manifest.checksumAlgorithm == "SHA-256", !manifest.appVersion.isEmpty, manifest.appVersion.count <= 64,
              manifest.appVersion.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-+").contains($0) }),
              ["iOS", "macOS"].contains(manifest.sourceDevice), manifest.createdAt.hasSuffix("Z"),
              formatter.date(from: manifest.createdAt) != nil, manifest.files.count < limits.entries,
              manifest.files.contains(where: { $0.path == "data.json" }),
              manifest.entityCounts.values.allSatisfy({ $0 >= 0 }) else { throw PortableBackupError.invalidManifest }
        var paths = Set<String>()
        for file in manifest.files {
            guard file.path != "manifest.json", Self.isAllowedPath(file.path), paths.insert(file.path).inserted,
                  file.byteCount >= 0, file.byteCount <= limits.entryBytes, file.sha256.count == 64,
                  file.sha256.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw PortableBackupError.invalidManifest }
        }
    }

    /// Versioned logical collections, not a SQLite file or executable SQL dump.
    /// The upcoming domain exporter is responsible for its strict field allowlists.
    private func payloadCounts(_ data: Data) throws -> [String: Int] {
        guard data.count <= limits.entryBytes else { throw PortableBackupError.resourceLimit }
        let value: Any
        do { value = try JSONSerialization.jsonObject(with: data) }
        catch { throw PortableBackupError.invalidPayload }
        guard let object = value as? [String: Any], Set(object.keys) == ["schemaVersion", "entities"],
              let version = object["schemaVersion"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(), version.intValue == Self.schemaVersion,
              version.doubleValue == Double(Self.schemaVersion), let entities = object["entities"] as? [String: Any] else {
            throw PortableBackupError.invalidPayload
        }
        let allowed: Set<String> = ["books", "editions", "libraryMemberships", "readings", "progressObservations",
            "journalEntries", "journalComponents", "journalCorrections", "quotes", "series", "seriesEntries",
            "challengeYears", "challengePrompts", "challengeAssignments", "challengeEvidence", "readerProfiles",
            "quests", "questLifecycle", "gamificationActivity", "xpAwards", "achievements", "cosmetics",
            "bestBookSelections", "attention", "proposals", "provenance", "importRuns", "importCandidates", "importOccurrences"]
        guard Set(entities.keys).isSubset(of: allowed) else { throw PortableBackupError.invalidPayload }
        var counts: [String: Int] = [:]
        var nodes = 0
        try rejectCredentials(value, depth: 0, nodes: &nodes)
        for (name, value) in entities {
            guard let records = value as? [[String: Any]] else { throw PortableBackupError.invalidPayload }
            counts[name] = records.count
        }
        return counts
    }

    private func rejectCredentials(_ value: Any, depth: Int, nodes: inout Int) throws {
        nodes += 1
        guard depth <= 64, nodes <= 500_000 else { throw PortableBackupError.resourceLimit }
        let forbidden: Set<String> = ["token", "accesstoken", "refreshtoken", "personalaccesstoken", "password", "authorization",
            "credential", "credentials", "privatekey", "apikey", "servicerole", "secret"]
        if let object = value as? [String: Any] {
            for (key, child) in object {
                let normalized = key.lowercased().filter { $0.isLetter || $0.isNumber }
                guard !forbidden.contains(normalized) else { throw PortableBackupError.credentialMaterial }
                try rejectCredentials(child, depth: depth + 1, nodes: &nodes)
            }
        } else if let array = value as? [Any] {
            for child in array { try rejectCredentials(child, depth: depth + 1, nodes: &nodes) }
        }
    }

    private func checkSizes(_ contents: [String: Data]) throws {
        guard contents.count <= limits.entries else { throw PortableBackupError.resourceLimit }
        var total = 0
        for (path, data) in contents {
            guard data.count <= limits.entryBytes, data.count <= limits.expandedBytes - total,
                  path != "manifest.json" || data.count <= limits.manifestBytes else { throw PortableBackupError.resourceLimit }
            total += data.count
        }
    }

    private static func isAllowedPath(_ path: String) -> Bool {
        path == "manifest.json" || path == "data.json" || isAssetPath(path)
    }
    private static func isAssetPath(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == "assets" else { return false }
        let file = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        guard file.count == 2, UUID(uuidString: String(file[0])) != nil,
              String(file[0]) == String(file[0]).lowercased(), ["png", "jpg", "jpeg", "heic", "pdf"].contains(String(file[1])) else { return false }
        return true
    }
    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    /// Reject multi-volume/ZIP64 and malformed/truncated directories before iteration.
    /// V1 resource limits do not require ZIP64; never silently accept a partial directory.
    private func zipEntryCount(_ data: Data) throws -> Int {
        guard data.count >= 22 else { throw PortableBackupError.invalidArchive }
        func u16(_ p: Int) -> Int { Int(data[p]) | Int(data[p + 1]) << 8 }
        func u32(_ p: Int) -> Int { u16(p) | u16(p + 2) << 16 }
        for p in stride(from: data.count - 22, through: max(0, data.count - 65_557), by: -1) {
            guard data[p] == 0x50, data[p + 1] == 0x4b, data[p + 2] == 0x05, data[p + 3] == 0x06,
                  p + 22 + u16(p + 20) == data.count else { continue }
            let count = u16(p + 10), size = u32(p + 12), offset = u32(p + 16)
            guard u16(p + 4) == 0, u16(p + 6) == 0, u16(p + 8) == count, count != 65_535,
                  offset <= p, size <= p - offset, offset + size == p else { throw PortableBackupError.invalidArchive }
            var cursor = offset
            var actualCount = 0
            while cursor < p {
                guard cursor <= p - 46, u32(cursor) == 0x02014b50 else { throw PortableBackupError.invalidArchive }
                let length = 46 + u16(cursor + 28) + u16(cursor + 30) + u16(cursor + 32)
                let local = u32(cursor + 42), compressed = u32(cursor + 20)
                guard length <= p - cursor, u16(cursor + 34) == 0, u16(cursor + 8) & 1 == 0,
                      local <= offset - 30, u32(local) == 0x04034b50 else { throw PortableBackupError.invalidArchive }
                let contentStart = local + 30 + u16(local + 26) + u16(local + 28)
                guard contentStart <= offset, compressed <= offset - contentStart,
                      u16(local + 8) == u16(cursor + 10) else { throw PortableBackupError.invalidArchive }
                actualCount += 1
                guard actualCount <= limits.entries else { throw PortableBackupError.resourceLimit }
                cursor += length
            }
            guard actualCount == count else { throw PortableBackupError.invalidArchive }
            return count
        }
        throw PortableBackupError.invalidArchive
    }
}
