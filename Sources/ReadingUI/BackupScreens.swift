import SwiftUI
import UniformTypeIdentifiers
import ReadingDomain

public struct BackupSettingsScreen:View {
    @EnvironmentObject private var model:BooksModel
    @Environment(\.colorScheme) private var scheme
    @State private var owner=""
    @State private var repository=""
    @State private var token=""
    @State private var message:String?
    @State private var exportURL:URL?
    @State private var restoreURL:URL?
    @State private var preview:RestorePreviewSummary?
    @State private var importing=false
    @State private var busy=false
    public init(visualQA:Bool=false){
        if visualQA {
            _owner=State(initialValue:"reader-example");_repository=State(initialValue:"reading-companion-private-backup")
            _token=State(initialValue:"github_pat_••••••••••••••••")
            _message=State(initialValue:"Private repository verified · manual backup ready")
            _preview=State(initialValue:.init(token:"qa",createdAt:"2026-10-08T08:30:00.000Z",incomingRecords:284,existingRecords:121,permanentXPAwardsAdded:3))
        }
    }
    public var body:some View { BooksScreen("Sync & Backup") {
        Text("Your library stays local-first. GitHub backups are manual, private snapshots; they are not continuous sync.")
            .foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
        section("PRIVATE GITHUB BACKUP") {
            BooksField(label:"GitHub owner",value:$owner)
            BooksField(label:"Dedicated private repository",value:$repository)
            SecureField("Fine-grained personal access token",text:$token).textContentType(.password)
                .textFieldStyle(.roundedBorder).frame(minHeight:44).accessibilityIdentifier("backup.pat")
            Text("Use a fine-grained token limited to this repository with Metadata read and Contents read/write. It is stored only in Keychain and is never included in a backup.")
                .font(DesignTokens.functionalFont(size:13)).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
            AppButton("Connect private repository") { connect() }.disabled(busy || owner.isEmpty || repository.isEmpty || token.isEmpty)
                .accessibilityIdentifier("backup.connect")
            AppButton("Create manual GitHub backup",kind:.secondary) { upload() }.disabled(busy)
                .accessibilityIdentifier("backup.upload")
        }
        section("PORTABLE BACKUP") {
            AppButton("Create local ZIP export") { export() }.disabled(busy).accessibilityIdentifier("backup.export")
            if let exportURL { ShareLink(item:exportURL) { Label("Share local export",systemImage:"square.and.arrow.up") }.frame(minHeight:44) }
            AppButton("Choose ZIP to preview",kind:.secondary) { importing=true }.disabled(busy).accessibilityIdentifier("backup.restore.choose")
            if let preview {
                VStack(alignment:.leading,spacing:8) {
                    Text("RESTORE PREVIEW").font(DesignTokens.functionalFont(size:12,weight:.semiBold))
                    Text("Created \(preview.createdAt)\n\(preview.incomingRecords) incoming records · \(preview.existingRecords) existing records\n\(preview.permanentXPAwardsAdded) permanent XP awards would be added.")
                        .fixedSize(horizontal:false,vertical:true)
                    Text("Existing local facts and permanent XP are preserved. Historical actions are not replayed.")
                        .font(DesignTokens.functionalFont(size:13)).foregroundStyle(DesignTokens.secondaryText(scheme))
                    AppButton("Confirm restore",kind:.tertiary) { confirmRestore() }.disabled(busy).accessibilityIdentifier("backup.restore.confirm")
                }.padding(16).background(DesignTokens.surface(scheme),in:RoundedRectangle(cornerRadius:14))
            }
        }
        if let message { Text(message).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("backup.result") }
    }.fileImporter(isPresented:$importing,allowedContentTypes:[UTType.zip],allowsMultipleSelection:false) { result in
        switch result { case .success(let urls): if let url=urls.first { previewRestore(url) }; case .failure: message="The selected archive could not be opened. Existing data is unchanged." }
    } }
    @ViewBuilder private func section<Content:View>(_ title:String,@ViewBuilder content:()->Content)->some View {
        VStack(alignment:.leading,spacing:12){Text(title).font(DesignTokens.functionalFont(size:12,weight:.semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme));content()}
    }
    private func connect(){ task { service in try await service.connectGitHub(owner:owner,repository:repository,personalAccessToken:token);token="";message="Private backup repository connected." } }
    private func upload(){ task { service in let sha=try await service.uploadManualBackup();message="Manual backup committed · \(sha.prefix(12))" } }
    private func export(){ task { service in exportURL=try await service.exportLocal();message="Portable backup is ready to share." } }
    private func previewRestore(_ url:URL){ task { service in
        let scoped=url.startAccessingSecurityScopedResource();defer{if scoped{url.stopAccessingSecurityScopedResource()}}
        restoreURL=url;preview=try await service.previewRestore(file:url);message="Integrity checks passed. Review the impact before confirming."
    } }
    private func confirmRestore(){ guard let restoreURL,let preview else{return};task { service in
        let scoped=restoreURL.startAccessingSecurityScopedResource();defer{if scoped{restoreURL.stopAccessingSecurityScopedResource()}}
        try await service.confirmRestore(file:restoreURL,previewToken:preview.token);self.preview=nil;message="Restore completed and post-restore integrity checks passed."
    } }
    private func task(_ operation:@escaping @MainActor (any BackupService) async throws->Void) {
        guard let service=model.backupService else{message="Backup service is unavailable.";return};busy=true
        Task { do { try await operation(service) } catch { message="The operation could not be completed. Existing local data and credentials are unchanged." };busy=false }
    }
}
