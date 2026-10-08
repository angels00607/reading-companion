import Foundation

public struct RestorePreviewSummary: Equatable, Sendable {
    public let token:String
    public let createdAt:String
    public let incomingRecords:Int
    public let existingRecords:Int
    public let permanentXPAwardsAdded:Int
    public init(token:String,createdAt:String,incomingRecords:Int,existingRecords:Int,permanentXPAwardsAdded:Int) {
        self.token=token;self.createdAt=createdAt;self.incomingRecords=incomingRecords
        self.existingRecords=existingRecords;self.permanentXPAwardsAdded=permanentXPAwardsAdded
    }
}

public protocol BackupService: Sendable {
    func connectGitHub(owner:String,repository:String,personalAccessToken:String) async throws
    func disconnectGitHub() async throws
    func exportLocal() async throws -> URL
    func uploadManualBackup() async throws -> String
    func previewRestore(file:URL) async throws -> RestorePreviewSummary
    func confirmRestore(file:URL,previewToken:String) async throws
}
