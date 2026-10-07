import XCTest
import CryptoKit
import ZIPFoundation
@testable import ReadingData

final class Phase9BackupTests: XCTestCase {
    private let codec = PortableBackupCodec()
    private let date = Date(timeIntervalSince1970: 1_791_382_400)
    private let json = Data(#"{"schemaVersion":1,"entities":{"books":[{"id":"book-1","title":"Unknown ≠ zero","pages":null}],"readings":[{"id":"reading-1","progressMode":"percentage","percentage":70,"pagePosition":null,"finishDate":"2024-02-03"}],"xpAwards":[]}}"#.utf8)
    private func encoded(_ data: Data? = nil, assets: [String: Data] = [:]) throws -> Data {
        try codec.encode(json: data ?? json, assets: assets, appVersion: "1.0.0", createdAt: date)
    }
    private func unpack(_ data: Data) throws -> [(String, Data, Entry.EntryType)] {
        let archive = try Archive(data: data, accessMode: .read)
        return try archive.map { entry in
            var bytes = Data(); _ = try archive.extract(entry) { bytes.append($0) }
            return (entry.path, bytes, entry.type)
        }
    }
    private func zip(_ files: [(String, Data, Entry.EntryType)]) throws -> Data {
        let archive = try Archive(accessMode: .create)
        for (path, data, type) in files {
            try archive.addEntry(with: path, type: type, uncompressedSize: Int64(data.count)) { position, size in
                let start = Int(position); return data.subdata(in: start..<min(start + size, data.count))
            }
        }
        return try XCTUnwrap(archive.data)
    }
    private func changingManifest(_ transform: (inout [String: Any]) -> Void) throws -> Data {
        var files = try unpack(encoded())
        let index = try XCTUnwrap(files.firstIndex { $0.0 == "manifest.json" })
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: files[index].1) as? [String: Any])
        transform(&object)
        files[index].1 = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return try zip(files)
    }
    func testRoundTripPreservesExactAuthoritativeJSONAndUnknowns() throws {
        let result = try codec.decode(encoded())
        XCTAssertEqual(result.json, json)
        XCTAssertEqual(result.manifest.entityCounts, ["books": 1, "readings": 1, "xpAwards": 0])
        XCTAssertEqual(result.manifest.backupFormatVersion, 1)
        XCTAssertEqual(result.manifest.schemaVersion, 1)
        XCTAssertEqual(result.manifest.appVersion, "1.0.0")
        XCTAssertTrue(result.manifest.createdAt.hasSuffix("Z"))
        XCTAssertEqual(result.manifest.sourceDevice, "iOS")
        XCTAssertEqual(result.manifest.checksumAlgorithm, "SHA-256")
    }
    func testAssetsHaveSHA256AndRemainIndependentFiles() throws {
        let path = "assets/00000000-0000-0000-0000-000000000001.png"
        let asset = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        let result = try codec.decode(encoded(assets: [path: asset]))
        XCTAssertEqual(result.assets, [path: asset])
        let file = try XCTUnwrap(result.manifest.files.first { $0.path == path })
        XCTAssertEqual(file.byteCount, asset.count)
        XCTAssertEqual(file.sha256, SHA256.hash(data: asset).map { String(format: "%02x", $0) }.joined())
    }
    func testPayloadTamperingRejectedBeforeAnyApplication() throws {
        var files = try unpack(encoded())
        let index = try XCTUnwrap(files.firstIndex { $0.0 == "data.json" })
        files[index].1 = Data(#"{"schemaVersion":1,"entities":{"books":[]}}"#.utf8)
        XCTAssertThrowsError(try codec.decode(zip(files))) { XCTAssertEqual($0 as? PortableBackupError, .integrityMismatch) }
    }
    func testAssetTamperingRejected() throws {
        let path = "assets/00000000-0000-0000-0000-000000000001.jpg"
        var files = try unpack(encoded(assets: [path: Data([1, 2, 3])]))
        let index = try XCTUnwrap(files.firstIndex { $0.0 == path }); files[index].1 = Data([3, 2, 1])
        XCTAssertThrowsError(try codec.decode(zip(files))) { XCTAssertEqual($0 as? PortableBackupError, .integrityMismatch) }
    }
    func testMissingDeclaredFileRejected() throws {
        let files = try unpack(encoded()).filter { $0.0 != "data.json" }
        XCTAssertThrowsError(try codec.decode(zip(files))) { XCTAssertEqual($0 as? PortableBackupError, .inventoryMismatch) }
    }
    func testUndeclaredAssetRejected() throws {
        var files = try unpack(encoded()); files.append(("assets/00000000-0000-0000-0000-000000000002.pdf", Data(), .file))
        XCTAssertThrowsError(try codec.decode(zip(files))) { XCTAssertEqual($0 as? PortableBackupError, .inventoryMismatch) }
    }
    func testDuplicateZIPNamesRejected() throws {
        var files = try unpack(encoded()); files.append(try XCTUnwrap(files.first { $0.0 == "data.json" }))
        XCTAssertThrowsError(try codec.decode(zip(files))) { XCTAssertEqual($0 as? PortableBackupError, .duplicateEntry) }
    }
    func testTraversalAbsoluteWindowsAndExecutablePathsRejected() throws {
        for path in ["../data.json", "/data.json", "assets/../data.json", "C:\\token", "assets\\token.png", "database.sqlite", "assets/token.sh"] {
            var files = try unpack(encoded()); files.append((path, Data(), .file))
            XCTAssertThrowsError(try codec.decode(zip(files))) { XCTAssertEqual($0 as? PortableBackupError, .unsafeEntry) }
        }
    }
    func testSymlinksNeverExtracted() throws {
        var files = try unpack(encoded()); files.append(("assets/00000000-0000-0000-0000-000000000002.png", Data("../../outside".utf8), .symlink))
        XCTAssertThrowsError(try codec.decode(zip(files))) { XCTAssertEqual($0 as? PortableBackupError, .unsafeEntry) }
    }
    func testUnknownFormatAndSchemaVersionsRejected() throws {
        for key in ["backupFormatVersion", "schemaVersion"] {
            let bytes = try changingManifest { $0[key] = 999 }
            XCTAssertThrowsError(try codec.decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .unsupportedVersion) }
        }
    }
    func testWrongCountsRejectedEvenWithIntactFileHash() throws {
        let bytes = try changingManifest { $0["entityCounts"] = ["books": 999] }
        XCTAssertThrowsError(try codec.decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .invalidPayload) }
    }
    func testMalformedHashAndNegativeSizeRejected() throws {
        for value in ["wrong", String(repeating: "G", count: 64)] {
            let bytes = try changingManifest { object in
                var files = object["files"] as! [[String: Any]]; files[0]["sha256"] = value; object["files"] = files
            }
            XCTAssertThrowsError(try codec.decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .invalidManifest) }
        }
        let bytes = try changingManifest { object in
            var files = object["files"] as! [[String: Any]]; files[0]["byteCount"] = -1; object["files"] = files
        }
        XCTAssertThrowsError(try codec.decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .invalidManifest) }
    }
    func testDeviceDescriptionCannotLeakPersonalOrHardwareIdentity() throws {
        for device in ["Sarah’s iPhone", "serial-123", "", "iOS\n"] {
            XCTAssertThrowsError(try codec.encode(json: json, appVersion: "1.0", createdAt: date, sourceDevice: device))
        }
    }
    func testCredentialsRejectedRecursivelyBeforePackaging() throws {
        for key in ["access_token", "refreshToken", "personal-access-token", "Authorization", "password", "privateKey", "api_key", "service_role"] {
            let value: [String: Any] = ["schemaVersion": 1, "entities": ["books": [["metadata": [key: "fictional-secret"]]]]]
            let data = try JSONSerialization.data(withJSONObject: value)
            XCTAssertThrowsError(try encoded(data)) { XCTAssertEqual($0 as? PortableBackupError, .credentialMaterial) }
        }
    }
    func testSQLiteOrSessionCollectionsCannotBecomePortableData() throws {
        for entity in ["sqlite_master", "outbox", "syncState", "sessions", "credentials"] {
            let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "entities": [entity: []]])
            XCTAssertThrowsError(try encoded(data)) { XCTAssertEqual($0 as? PortableBackupError, .invalidPayload) }
        }
    }
    func testMalformedJSONAndNonintegerSchemaRejected() throws {
        for text in ["not JSON", "[]", #"{"schemaVersion":true,"entities":{}}"#, #"{"schemaVersion":1.5,"entities":{}}"#, #"{"schemaVersion":1,"entities":{"books":[1]}}"#] {
            XCTAssertThrowsError(try encoded(Data(text.utf8)))
        }
    }
    func testExpandedAndCompressedResourceLimitsRejectWholeArchive() throws {
        let bytes = try encoded()
        var limits = PortableBackupLimits(); limits.archiveBytes = bytes.count - 1
        XCTAssertThrowsError(try PortableBackupCodec(limits: limits).decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .resourceLimit) }
        limits = PortableBackupLimits(); limits.expandedBytes = json.count - 1
        XCTAssertThrowsError(try PortableBackupCodec(limits: limits).decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .resourceLimit) }
        limits = PortableBackupLimits(); limits.entries = 1
        XCTAssertThrowsError(try PortableBackupCodec(limits: limits).decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .resourceLimit) }
    }
    func testHighlyCompressedOversizeJSONRejectedBeforeDecompression() throws {
        let large = Data((#"{"schemaVersion":1,"entities":{"books":[{"title":""# + String(repeating: "a", count: 100_000) + #""}]}}"#).utf8)
        let bytes = try encoded(large)
        var limits = PortableBackupLimits(); limits.entryBytes = 1024
        XCTAssertThrowsError(try PortableBackupCodec(limits: limits).decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .resourceLimit) }
    }
    func testTruncatedAndCorruptZIPRejected() throws {
        let bytes = try encoded()
        for data in [Data(), Data(bytes.dropLast()), Data(bytes.prefix(50)), Data(repeating: 0, count: bytes.count)] {
            XCTAssertThrowsError(try codec.decode(data)) { XCTAssertEqual($0 as? PortableBackupError, .invalidArchive) }
        }
    }
    func testWritesInteroperabilityFixtureWhenRequestedByCI() throws {
        let bytes = try encoded()
        if let path = ProcessInfo.processInfo.environment["PHASE9_INTEROPERABILITY_FILE"] {
            try bytes.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        XCTAssertEqual(try codec.decode(bytes).json, json)
    }
    func testCentralDirectoryCannotHideUnvalidatedExtraEntry() throws {
        var bytes = try encoded()
        let offset = bytes.count - 22
        // Lie about one of the two physical central-directory entries.
        bytes[offset + 8] = 1; bytes[offset + 9] = 0
        bytes[offset + 10] = 1; bytes[offset + 11] = 0
        XCTAssertThrowsError(try codec.decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .invalidArchive) }
    }
    func testManifestTimestampMustBeValidUTC() throws {
        for value in ["2026-10-07", "invalidZ", "2026-10-07T12:00:00.000+02:00"] {
            let bytes = try changingManifest { $0["createdAt"] = value }
            XCTAssertThrowsError(try codec.decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .invalidManifest) }
        }
    }
    func testDuplicateManifestDescriptorsRejected() throws {
        let bytes = try changingManifest { object in
            var files = object["files"] as! [[String: Any]]; files.append(files[0]); object["files"] = files
        }
        XCTAssertThrowsError(try codec.decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .invalidManifest) }
    }
    func testDirectoryEntriesRejectedWithoutFilesystemWrites() throws {
        var files = try unpack(encoded()); files.append(("assets/", Data(), .directory))
        XCTAssertThrowsError(try codec.decode(zip(files))) { XCTAssertEqual($0 as? PortableBackupError, .unsafeEntry) }
    }
    func testAmbiguousDuplicateJSONKeysIncludingEscapesRejected() throws {
        for text in [#"{"schemaVersion":1,"schemaVersion":1,"entities":{}}"#,
                     #"{"schemaVersion":1,"entities":{"books":[{"title":"A","title":"B"}]}}"#,
                     #"{"schemaVersion":1,"entities":{"books":[{"title":"A","\u0074itle":"B"}]}}"#] {
            XCTAssertThrowsError(try encoded(Data(text.utf8))) { XCTAssertEqual($0 as? PortableBackupError, .invalidPayload) }
        }
    }
    func testExcessiveJSONNestingRejectedBeforeFoundationDecode() throws {
        let text = #"{"schemaVersion":1,"entities":{"books":[{"nested":"# + String(repeating: "[", count: 100) + "0" + String(repeating: "]", count: 100) + "}]}}"
        XCTAssertThrowsError(try encoded(Data(text.utf8))) { XCTAssertEqual($0 as? PortableBackupError, .resourceLimit) }
    }
    func testUnrecognizedManifestFieldsRejectedInsteadOfIgnoringSecrets() throws {
        let bytes = try changingManifest { $0["accessToken"] = "fictional" }
        XCTAssertThrowsError(try codec.decode(bytes)) { XCTAssertEqual($0 as? PortableBackupError, .invalidManifest) }
    }
    func testDataSliceOffsetsCannotCrashArchiveValidation() throws {
        let bytes = try encoded(); let wrapped = Data([0xff]) + bytes
        XCTAssertEqual(try codec.decode(wrapped.dropFirst()).json, json)
    }
}
