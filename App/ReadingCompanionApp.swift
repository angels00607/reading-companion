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
                    else { FoundationShell(homeContent: AnyView(BooksHome()), journalContent: AnyView(JournalHome())).environmentObject(model) }
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
            let qa = ProcessInfo.processInfo.arguments.contains("-phase2-fixture") || ProcessInfo.processInfo.arguments.contains("-phase3-fixture")
            #else
            let qa = false
            #endif
            let store = try LocalStore(path: qa ? ":memory:" : root.appendingPathComponent(owner.uuidString + ".sqlite").path, ownerID: owner)
            if ProcessInfo.processInfo.arguments.contains("-phase3-fixture") { try seedJournalQA(store) }
            model = BooksModel(repository: store, journalRepository: store, provider: qa ? BooksAcceptanceProvider() : OpenLibraryProvider(), assetDirectory: root.appendingPathComponent(owner.uuidString + "-covers"))
        } catch { storageError = "Could not open the local database. Existing files have not been reset or deleted." }
    }
    private func seedJournalQA(_ store: LocalStore) throws {
        let first = try store.add(work: WorkCandidate(provider: "qa", reference: "journal-1", title: "The Very Long Title of a Book Remembered in a Handwritten Journal", author: "Alexandra Example"))
        let reading = try store.start(bookID: first, editionID: nil, date: try ReadingDate(year: 2026, month: 9, day: 4))
        try store.finish(readingID: reading, confirmed: true, date: try ReadingDate(year: 2026, month: 9, day: 28), revision: 0)
        try store.saveBookReview(readingID: reading, draft: BookReviewDraft(summary: "A thoughtful summary written by the reader, ready to copy into the physical journal.", pageCount: 384, rating: .stars(5), format: .hardcover, start: try ReadingDate(year: 2026, month: 9, day: 4), finish: try ReadingDate(year: 2026, month: 9, day: 28)))
        try store.setFavorite(bookID: first, decision: .selected)
        try store.saveQuote(JournalQuote(bookID: first, readingID: reading, text: "A representative quote for visual review.", source: "p. 184", includeInJournal: true))
        try store.markBookReviewCopied(readingID: reading)
        try store.saveBookReview(readingID: reading, draft: BookReviewDraft(summary: "A corrected summary that now differs from the version copied on paper.", pageCount: 384, rating: .stars(5), format: .hardcover, start: try ReadingDate(year: 2026, month: 9, day: 4), finish: try ReadingDate(year: 2026, month: 9, day: 28)))
        let second = try store.add(work: WorkCandidate(provider: "qa", reference: "journal-2", title: "A Pending Review", author: "Morgan Reader"))
        let secondReading = try store.start(bookID: second, editionID: nil, date: nil)
        try store.finish(readingID: secondReading, confirmed: true, date: nil, revision: 0)
        let third = try store.add(work: WorkCandidate(provider: "qa", reference: "journal-3", title: "Ready for the Next Journal Session", author: "Jamie Writer"))
        let thirdReading = try store.start(bookID: third, editionID: nil, date: nil)
        try store.finish(readingID: thirdReading, confirmed: true, date: nil, revision: 0)
        try store.saveBookReview(readingID: thirdReading, draft: BookReviewDraft(summary: "Ready to be copied during a focused session.", pageCount: nil, rating: .noRating, format: .ebook, start: nil, finish: nil))
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
