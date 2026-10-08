import Foundation
import ReadingDomain

public actor Phase9BackupService: BackupService {
    private let store:LocalStore
    private let assetDirectory:URL
    private let credentials:any CredentialStore
    private var transport:GitHubBackupTransport?
    private var repository:GitHubBackupRepository?
    private var previews:[String:(BackupPreview,Data)] = [:]
    public init(store:LocalStore,assetDirectory:URL,credentials:any CredentialStore) {
        self.store=store;self.assetDirectory=assetDirectory;self.credentials=credentials
    }
    public func connectGitHub(owner:String,repository:String,personalAccessToken:String) async throws {
        let destination=try GitHubBackupRepository(owner:owner.trimmingCharacters(in:.whitespacesAndNewlines),name:repository.trimmingCharacters(in:.whitespacesAndNewlines))
        let value=GitHubBackupTransport(repository:destination,credentials:credentials)
        try await value.connect(personalAccessToken:personalAccessToken)
        self.repository=destination;self.transport=value
    }
    public func disconnectGitHub() async throws {
        guard let transport else { throw GitHubBackupError.authenticationRequired }
        try await transport.disconnect();self.transport=nil;self.repository=nil
    }
    public func exportLocal() async throws -> URL {
        let archive=try store.makePortableBackup(appVersion:"9.0",assets:try assets())
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("reading-companion-\(UUID().uuidString.lowercased()).zip")
        try archive.write(to:url,options:.atomic);return url
    }
    public func uploadManualBackup() async throws -> String {
        guard let transport else { throw GitHubBackupError.authenticationRequired }
        let data=try store.makePortableBackup(appVersion:"9.0",assets:try assets())
        let version=try await transport.upload(data,versionID:UUID());return version.commitSHA
    }
    public func previewRestore(file:URL) async throws -> RestorePreviewSummary {
        let data=try Data(contentsOf:file,options:.mappedIfSafe);let value=try store.previewPortableRestore(data)
        previews[value.token]=(value,data)
        return .init(token:value.token,createdAt:value.createdAt,incomingRecords:value.incomingRecords,
                     existingRecords:value.existingRecords,permanentXPAwardsAdded:value.permanentXPAwardsAdded)
    }
    public func confirmRestore(file:URL,previewToken:String) async throws {
        guard let cached=previews.removeValue(forKey:previewToken) else { throw BackupRestoreError.stalePreview }
        let (preview,data)=cached
        try store.restorePortableBackup(data,preview:preview,confirmed:true)
    }
    private func assets() throws -> [String:Data] {
        guard FileManager.default.fileExists(atPath:assetDirectory.path) else{return[:]}
        var result=[String:Data]()
        for url in try FileManager.default.contentsOfDirectory(at:assetDirectory,includingPropertiesForKeys:[.isRegularFileKey],options:[.skipsHiddenFiles]) {
            guard (try url.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile)==true else{continue}
            let parts=url.lastPathComponent.split(separator:".",omittingEmptySubsequences:false)
            guard parts.count==2,let id=UUID(uuidString:String(parts[0])),["png","jpg","jpeg","heic","pdf"].contains(parts[1].lowercased()) else{continue}
            result["assets/\(id.uuidString.lowercased()).\(parts[1].lowercased())"]=try Data(contentsOf:url,options:.mappedIfSafe)
        }
        return result
    }
}
