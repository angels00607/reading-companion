import SwiftUI
import ReadingUI
import ReadingData
import ReadingDomain

@main
struct ReadingCompanionApp: App {
    @State private var model: BooksModel?
    @State private var storageError: String?
    var body: some Scene {
        WindowGroup {
            Group {
                if isFoundationQA { FoundationShell() }
                else if let model {
                    if let route = visualQARoute { BooksVisualQA(route: route).environmentObject(model) }
                    else { FoundationShell(homeContent: AnyView(BooksHome())).environmentObject(model) }
                }
                else if let storageError { StatePresentation(kind: .error, title: "Library unavailable", message: storageError) }
                else { SkeletonRow() }
            }.preferredColorScheme(acceptanceAppearance)
                .onAppear {
                    if !isFoundationQA && model == nil { openStore() }
                    #if DEBUG
                    Phase0Diagnostics.shared.start()
                    #endif
                }
        }
    }
    private var isFoundationQA: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-phase0-diagnostics")
        #else
        return false
        #endif
    }
    private var visualQARoute: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-phase2-screen"), index + 1 < args.count { return args[index + 1] }
        #endif
        return nil
    }
    @MainActor private func openStore() {
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("ReadingCompanion", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            // Local-only owner identity until approved auth/onboarding integration. Never sent as an auth credential.
            let identity = root.appendingPathComponent("local-owner.txt")
            let owner: UUID
            if FileManager.default.fileExists(atPath: identity.path) {
                guard let value = UUID(uuidString: try String(contentsOf: identity, encoding: .utf8)) else { throw BooksError.invalidMetadata }
                owner = value
            } else { owner = UUID(); try owner.uuidString.write(to: identity, atomically: true, encoding: .utf8) }
            #if DEBUG
            let qa = ProcessInfo.processInfo.arguments.contains("-phase2-fixture")
            #else
            let qa = false
            #endif
            let store = try LocalStore(path: qa ? ":memory:" : root.appendingPathComponent(owner.uuidString + ".sqlite").path, ownerID: owner)
            model = BooksModel(repository: store, provider: qa ? BooksAcceptanceProvider() : OpenLibraryProvider(), assetDirectory: root.appendingPathComponent(owner.uuidString + "-covers"))
        } catch { storageError = "Could not open the local database. Existing files have not been reset or deleted." }
    }

    private var acceptanceAppearance: ColorScheme? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-phase0-appearance"), index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "Dark": return .dark
            case "Light": return .light
            default: break
            }
        }
        #endif
        return nil // Normal launches and Release builds follow the system.
    }
}
