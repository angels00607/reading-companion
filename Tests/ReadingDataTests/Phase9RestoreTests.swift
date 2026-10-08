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
