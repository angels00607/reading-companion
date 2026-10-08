import Foundation
import ReadingDomain

public actor Phase9BackupService: BackupService {
    private struct SavedRepository:Codable { let owner:String;let name:String }
    private let store:LocalStore
    private let assetDirectory:URL
    private let credentials:any CredentialStore
    private let client:any GitHubBackupHTTPClient
    private let configuration:UserDefaults
    private let beforeAssetCommit:(@Sendable () throws -> Void)?
    private var transport:GitHubBackupTransport?
    private var repository:GitHubBackupRepository?
    private var previews:[String:(BackupPreview,Data)] = [:]
    private let configurationKey:String
    public init(store:LocalStore,assetDirectory:URL,credentials:any CredentialStore,
                client:any GitHubBackupHTTPClient = GitHubBackupURLSessionClient(),
                configuration:UserDefaults = .standard,
                beforeAssetCommit:(@Sendable () throws -> Void)? = nil) {
        self.store=store;self.assetDirectory=assetDirectory;self.credentials=credentials
        self.client=client;self.configuration=configuration;self.beforeAssetCommit=beforeAssetCommit
        self.configurationKey="ReadingCompanion.githubBackup.\(assetDirectory.lastPathComponent)"
        if let data=configuration.data(forKey:configurationKey),
           let saved=try? JSONDecoder().decode(SavedRepository.self,from:data),
           let destination=try? GitHubBackupRepository(owner:saved.owner,name:saved.name) {
            self.repository=destination
            self.transport=GitHubBackupTransport(repository:destination,credentials:credentials,client:client)
        }
    }
    public func connectGitHub(owner:String,repository:String,personalAccessToken:String) async throws {
        let destination=try GitHubBackupRepository(owner:owner.trimmingCharacters(in:.whitespacesAndNewlines),name:repository.trimmingCharacters(in:.whitespacesAndNewlines))
        let value=GitHubBackupTransport(repository:destination,credentials:credentials,client:client)
        try await value.connect(personalAccessToken:personalAccessToken)
        let saved=try JSONEncoder().encode(SavedRepository(owner:destination.owner,name:destination.name))
        configuration.set(saved,forKey:configurationKey)
        self.repository=destination;self.transport=value
    }
    public func disconnectGitHub() async throws {
        guard let transport else { throw GitHubBackupError.authenticationRequired }
        try await transport.disconnect();configuration.removeObject(forKey:configurationKey);self.transport=nil;self.repository=nil
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
        let decoded=try PortableBackupCodec().decode(data)
        let assets=try AssetRestoreTransaction(directory:assetDirectory,incoming:decoded.assets,beforeCommit:beforeAssetCommit)
        defer{assets.finish()}
        try store.restorePortableBackup(data,preview:preview,confirmed:true,applyExternal:{try assets.apply()},rollbackExternal:{assets.rollback()})
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

private final class AssetRestoreTransaction:@unchecked Sendable {
    private let fileManager=FileManager.default
    private let destination:URL
    private let staging:URL
    private let displaced:URL
    private let beforeCommit:(@Sendable () throws -> Void)?
    private var displacedExisting=false
    private var installed=false

    init(directory:URL,incoming:[String:Data],beforeCommit:(@Sendable () throws -> Void)?) throws {
        destination=directory
        let parent=directory.deletingLastPathComponent(),id=UUID().uuidString.lowercased()
        staging=parent.appendingPathComponent(".phase9-assets-staging-"+id,isDirectory:true)
        displaced=parent.appendingPathComponent(".phase9-assets-rollback-"+id,isDirectory:true)
        self.beforeCommit=beforeCommit
        try fileManager.createDirectory(at:parent,withIntermediateDirectories:true)
        try fileManager.createDirectory(at:staging,withIntermediateDirectories:false)
        do {
            if fileManager.fileExists(atPath:destination.path) {
                let values=try destination.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
                guard values.isDirectory==true,values.isSymbolicLink != true else{throw BackupRestoreError.invalidValue}
                for url in try fileManager.contentsOfDirectory(at:destination,includingPropertiesForKeys:[.isRegularFileKey,.isSymbolicLinkKey],options:[.skipsHiddenFiles]) {
                    guard Self.validName(url.lastPathComponent),
                          (try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])).isRegularFile==true,
                          (try url.resourceValues(forKeys:[.isSymbolicLinkKey])).isSymbolicLink != true else{throw BackupRestoreError.invalidValue}
                    try fileManager.copyItem(at:url,to:staging.appendingPathComponent(url.lastPathComponent))
                }
            }
            for (path,data) in incoming {
                let name=URL(fileURLWithPath:path).lastPathComponent
                guard path=="assets/"+name,Self.validName(name) else{throw PortableBackupError.unsafeEntry}
                let target=staging.appendingPathComponent(name)
                if fileManager.fileExists(atPath:target.path) {
                    guard try Data(contentsOf:target,options:.mappedIfSafe)==data else{throw BackupRestoreError.invalidValue}
                } else { try data.write(to:target,options:.atomic) }
            }
        } catch { try? fileManager.removeItem(at:staging);throw error }
    }
    func apply() throws {
        do {
            if fileManager.fileExists(atPath:destination.path) {
                try fileManager.moveItem(at:destination,to:displaced);displacedExisting=true
            }
            try beforeCommit?()
            try fileManager.moveItem(at:staging,to:destination);installed=true
        } catch { rollback();throw error }
    }
    func rollback() {
        if installed { try? fileManager.removeItem(at:destination);installed=false }
        if displacedExisting {
            try? fileManager.moveItem(at:displaced,to:destination);displacedExisting=false
        }
    }
    func finish() {
        if fileManager.fileExists(atPath:staging.path){try? fileManager.removeItem(at:staging)}
        if fileManager.fileExists(atPath:displaced.path){try? fileManager.removeItem(at:displaced)}
    }
    private static func validName(_ name:String)->Bool {
        let parts=name.split(separator:".",omittingEmptySubsequences:false)
        return parts.count==2 && UUID(uuidString:String(parts[0])) != nil && ["png","jpg","jpeg","heic","pdf"].contains(parts[1].lowercased())
    }
}
