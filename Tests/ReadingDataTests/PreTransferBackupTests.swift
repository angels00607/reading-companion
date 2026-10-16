import Foundation
import XCTest
import ReadingDomain
@testable import ReadingData

final class PreTransferBackupTests: XCTestCase {
    func testBackupIsCreatedAndNeverOverwritesExistingBackup() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try LocalStore(path: root.appendingPathComponent("library.sqlite").path,
                                   ownerID: UUID())
        let destination = root.appendingPathComponent("backup.sqlite")
        XCTAssertEqual(try store.createPreTransferBackup(at: destination), destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertThrowsError(try store.createPreTransferBackup(at: destination))
    }
}
