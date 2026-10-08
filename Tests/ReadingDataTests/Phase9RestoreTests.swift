import XCTest
import GRDB
import ReadingDomain
@testable import ReadingData

final class Phase9RestoreTests: XCTestCase {
    private func store(_ owner: UUID = UUID()) throws -> LocalStore { try LocalStore(path:":memory:",ownerID:owner) }

    func testTypedExportPreviewConfirmedRestoreAndIdempotentPermanentXPUnion() throws {
        let source = try store()
        let book = try source.add(work:.init(provider:"manual",reference:"portable",title:"Portable",author:"Reader"),choice:.addAnyway)
        let reading = try source.start(bookID:book,editionID:nil,date:nil)
        _ = try source.update(readingID:reading,value:.pages(current:42),revision:0,observationID:UUID())
        let archive = try source.makePortableBackup(appVersion:"9.0",createdAt:Date(timeIntervalSince1970:1234))

        let target = try store()
        let preview = try target.previewPortableRestore(archive)
        XCTAssertGreaterThan(preview.incomingRecords,0)
        XCTAssertThrowsError(try target.restorePortableBackup(archive,preview:preview,confirmed:false)) {
            XCTAssertEqual($0 as? BackupRestoreError,.confirmationRequired)
        }
        try target.restorePortableBackup(archive,preview:preview,confirmed:true)
        XCTAssertEqual(try target.bookCount(),1)
        let observations = try target.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM progress_observations") }
        XCTAssertEqual(observations,1)
        let outbox = try target.queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM outbox") }
        XCTAssertEqual(outbox,0)
        let second = try target.previewPortableRestore(archive)
        try target.restorePortableBackup(archive,preview:second,confirmed:true)
        XCTAssertEqual(try target.bookCount(),1)
    }

    func testRestoreRejectsStalePreviewWithoutPartialWrites() throws {
        let source = try store(); _ = try source.add(work:.init(provider:"manual",reference:"one",title:"One",author:"Reader"),choice:.addAnyway)
        let archive = try source.makePortableBackup(appVersion:"9.0")
        let target = try store(); let preview = try target.previewPortableRestore(archive)
        _ = try target.add(work:.init(provider:"manual",reference:"local",title:"Local",author:"Reader"),choice:.addAnyway)
        XCTAssertThrowsError(try target.restorePortableBackup(archive,preview:preview,confirmed:true)) {
            XCTAssertEqual($0 as? BackupRestoreError,.stalePreview)
        }
        XCTAssertEqual(try target.bookCount(),1)
    }

    func testRestoreRejectsStalePreviewWhenValuesChangeButCountsDoNot() throws {
        let source=try store();_ = try source.add(work:.init(provider:"manual",reference:"source",title:"Source",author:"Reader"),choice:.addAnyway)
        let archive=try source.makePortableBackup(appVersion:"9.0")
        let target=try store();let id=try target.add(work:.init(provider:"manual",reference:"local",title:"Before",author:"Reader"),choice:.addAnyway)
        let preview=try target.previewPortableRestore(archive)
        try target.queue.write{$0.execute(sql:"UPDATE books SET title=? WHERE owner_id=? AND id=?",arguments:["After",target.ownerID.uuidString,id.uuidString])}
        XCTAssertThrowsError(try target.restorePortableBackup(archive,preview:preview,confirmed:true)) {
            XCTAssertEqual($0 as? BackupRestoreError,.stalePreview)
        }
        XCTAssertEqual(try target.record(id:id).book.title,"After")
    }

    func testAssetRestoreStagesPreservesExistingFilesAndRollsBackDatabaseOnFailure() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        defer{try? FileManager.default.removeItem(at:root)}
        let assets=root.appendingPathComponent("assets",isDirectory:true);try FileManager.default.createDirectory(at:assets,withIntermediateDirectories:true)
        let existingName=UUID().uuidString.lowercased()+".png",incomingName=UUID().uuidString.lowercased()+".jpg"
        try Data("existing".utf8).write(to:assets.appendingPathComponent(existingName))
        let source=try store();_ = try source.add(work:.init(provider:"manual",reference:"asset",title:"Asset",author:"Reader"),choice:.addAnyway)
        let archive=try source.makePortableBackup(appVersion:"9.0",assets:["assets/"+incomingName:Data("incoming".utf8)])
        let file=root.appendingPathComponent("backup.zip");try archive.write(to:file)
        let target=try store(),service=Phase9BackupService(store:target,assetDirectory:assets,credentials:BackupMemoryCredentialStore(),beforeAssetCommit:{throw BackupRestoreError.postRestoreIntegrity})
        let preview=try await service.previewRestore(file:file)
        await XCTAssertThrowsErrorAsync(try await service.confirmRestore(file:file,previewToken:preview.token))
        XCTAssertEqual(try target.bookCount(),0)
        XCTAssertEqual(try Data(contentsOf:assets.appendingPathComponent(existingName)),Data("existing".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath:assets.appendingPathComponent(incomingName).path))
    }

    func testAssetRestoreRefusesDifferentBytesAtExistingPathWithoutDatabaseWrites() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        defer{try? FileManager.default.removeItem(at:root)}
        let assets=root.appendingPathComponent("assets",isDirectory:true);try FileManager.default.createDirectory(at:assets,withIntermediateDirectories:true)
        let name=UUID().uuidString.lowercased()+".png";try Data("local".utf8).write(to:assets.appendingPathComponent(name))
        let source=try store();_ = try source.add(work:.init(provider:"manual",reference:"collision",title:"Collision",author:"Reader"),choice:.addAnyway)
        let archive=try source.makePortableBackup(appVersion:"9.0",assets:["assets/"+name:Data("remote".utf8)])
        let file=root.appendingPathComponent("backup.zip");try archive.write(to:file)
        let target=try store(),service=Phase9BackupService(store:target,assetDirectory:assets,credentials:BackupMemoryCredentialStore())
        let preview=try await service.previewRestore(file:file)
        await XCTAssertThrowsErrorAsync(try await service.confirmRestore(file:file,previewToken:preview.token))
        XCTAssertEqual(try target.bookCount(),0)
        XCTAssertEqual(try Data(contentsOf:assets.appendingPathComponent(name)),Data("local".utf8))
    }

    func testAssetRestoreInstallsNewFileWithoutOverwritingExistingFile() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        defer{try? FileManager.default.removeItem(at:root)}
        let assets=root.appendingPathComponent("assets",isDirectory:true);try FileManager.default.createDirectory(at:assets,withIntermediateDirectories:true)
        let existing=UUID().uuidString.lowercased()+".png",incoming=UUID().uuidString.lowercased()+".jpg"
        try Data("keep".utf8).write(to:assets.appendingPathComponent(existing))
        let source=try store();_ = try source.add(work:.init(provider:"manual",reference:"success",title:"Success",author:"Reader"),choice:.addAnyway)
        let archive=try source.makePortableBackup(appVersion:"9.0",assets:["assets/"+incoming:Data("install".utf8)])
        let file=root.appendingPathComponent("backup.zip");try archive.write(to:file)
        let target=try store(),service=Phase9BackupService(store:target,assetDirectory:assets,credentials:BackupMemoryCredentialStore())
        let preview=try await service.previewRestore(file:file)
        try await service.confirmRestore(file:file,previewToken:preview.token)
        XCTAssertEqual(try target.bookCount(),1)
        XCTAssertEqual(try Data(contentsOf:assets.appendingPathComponent(existing)),Data("keep".utf8))
        XCTAssertEqual(try Data(contentsOf:assets.appendingPathComponent(incoming)),Data("install".utf8))
    }

    func testRelationshipFailureRollsBackEntireRestore() throws {
        let source=try store();_ = try source.add(work:.init(provider:"manual",reference:"rollback",title:"Rollback",author:"Reader"),choice:.addAnyway)
        let original=try source.makePortableBackup(appVersion:"9.0")
        let decoded=try PortableBackupCodec().decode(original)
        var object=try XCTUnwrap(try JSONSerialization.jsonObject(with:decoded.json) as? [String:Any])
        var entities=try XCTUnwrap(object["entities"] as? [String:Any])
        var memberships=try XCTUnwrap(entities["libraryMemberships"] as? [[String:Any]])
        var fields=try XCTUnwrap(memberships[0]["fields"] as? [String:Any])
        fields["book_id"]=["type":"text","text":UUID().uuidString];memberships[0]["fields"]=fields
        entities["libraryMemberships"]=memberships;object["entities"]=entities
        let tampered=try PortableBackupCodec().encode(json:try JSONSerialization.data(withJSONObject:object,options:[.sortedKeys]),appVersion:"9.0",createdAt:Date())
        let target=try store(),preview=try target.previewPortableRestore(tampered)
        XCTAssertThrowsError(try target.restorePortableBackup(tampered,preview:preview,confirmed:true))
        XCTAssertEqual(try target.bookCount(),0)
    }
}

private final class BackupMemoryCredentialStore:CredentialStore,@unchecked Sendable {
    func read(account:String)throws->Data?{nil};func write(_ data:Data,account:String)throws{};func remove(account:String)throws{}
}

private func XCTAssertThrowsErrorAsync<T>(_ expression:@autoclosure () async throws->T,_ file:StaticString=#filePath,_ line:UInt=#line) async {
    do{_ = try await expression();XCTFail("Expected error",file:file,line:line)}catch{}
}
