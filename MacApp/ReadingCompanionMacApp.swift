import SwiftUI
import AuthenticationServices
import CryptoKit
import Security
import ReadingUI
import ReadingData
import ReadingDomain

@main
struct ReadingCompanionMacApp: App {
    @State private var appleSignIn = MacAppleSignInState()

    var body: some Scene {
        WindowGroup("Reading Companion") {
            VStack(spacing: 0) {
                MacAppleSignInPanel(state: appleSignIn)
                Divider()
                FoundationShell(homeContent: AnyView(MacLibraryView()),
                            journalContent: AnyView(MacJournalView()),
                            seriesContent: AnyView(MacSeriesView()))
                .frame(minWidth: 760, minHeight: 520)
            }
        }
        .defaultSize(width: 1100, height: 760)
    }
}


@MainActor @Observable
private final class MacAppleSignInState {
    private(set) var accountLabel: String?
    private(set) var errorMessage: String?
    private var pendingNonce: String?

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try secureNonce()
            pendingNonce = nonce
            request.nonce = SHA256.hash(data: Data(nonce.utf8))
                .map { String(format: "%02x", $0) }.joined()
            request.requestedScopes = [.email]
            errorMessage = nil
        } catch {
            pendingNonce = nil
            errorMessage = "Unable to prepare a secure Apple sign-in request."
        }
    }

    func handle(_ result: Result<ASAuthorization, Error>) {
        defer { pendingNonce = nil }
        switch result {
        case .failure(let error):
            errorMessage = "Apple sign-in failed: \\(error.localizedDescription)"
        case .success(let authorization):
            guard pendingNonce != nil,
                  let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  !credential.user.isEmpty,
                  let token = credential.identityToken,
                  !token.isEmpty else {
                errorMessage = "Apple sign-in response could not be validated locally."
                return
            }
            // An Apple credential alone is NOT an authenticated Supabase session.
            // A future cloud exchange must use this request's raw nonce and the
            // identity token, then verify the returned Supabase user before any
            // local owner migration. Do not persist either value here.
            accountLabel = "Apple authorization received — cloud not connected"
            errorMessage = nil
        }
    }

    private func secureNonce(length: Int = 32) throws -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CocoaError(.fileReadUnknown)
        }
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }
}

private struct MacAppleSignInPanel: View {
    let state: MacAppleSignInState

    var body: some View {
        HStack(spacing: 12) {
            SignInWithAppleButton(.signIn, onRequest: state.prepare, onCompletion: state.handle)
                .signInWithAppleButtonStyle(.black)
                .frame(width: 190, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text("Apple Account").font(.headline)
                Text(state.accountLabel ?? "Local-only library. Cloud account not connected.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = state.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// A real, device-local library. Cross-device sync is deliberately not implied.
private struct MacLibraryView: View {
    @State private var store: LocalStore?
    @State private var books: [CatalogRecord] = []
    @State private var search = ""
    @State private var libraryView: LibraryView = .all
    @State private var librarySort: LibrarySort = .recentlyAdded
    @State private var newTitle = ""
    @State private var newAuthor = ""
    @State private var showingAdd = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Library").font(.title2.bold())
                Spacer()
                Button("Add Book", systemImage: "plus") { showingAdd = true }
                    .disabled(store == nil)
            }
            TextField("Search by title or author", text: $search)
                .textFieldStyle(.roundedBorder)
                .onChange(of: search) { _, _ in refresh() }
            HStack {
                Picker("Books", selection: $libraryView) {
                    Text("All").tag(LibraryView.all)
                    Text("To Read").tag(LibraryView.toRead)
                    Text("Read").tag(LibraryView.read)
                }
                .pickerStyle(.segmented)
                .onChange(of: libraryView) { _, _ in refresh() }
                Picker("Sort by", selection: $librarySort) {
                    Text("Recently Added").tag(LibrarySort.recentlyAdded)
                    Text("Title A–Z").tag(LibrarySort.title)
                    Text("Author A–Z").tag(LibrarySort.author)
                    Text("Recently Finished").tag(LibrarySort.recentlyFinished)
                }
                .onChange(of: librarySort) { _, _ in refresh() }
                .frame(maxWidth: 220)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
                    .accessibilityIdentifier("macLibrary.error")
            }
            if books.isEmpty {
                ContentUnavailableView("No books found", systemImage: "books.vertical",
                                       description: Text("Add a book to begin your Mac library."))
            } else {
                ScrollView {
                  LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(books, id: \.book.id) { record in
                        HStack {
                            Image(systemName: "book.closed").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.book.title).font(.headline)
                                Text(record.book.author).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                  }
                }
            }
            Text("Stored locally on this Mac. iPhone synchronization is not yet available.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .task { openStore() }
        .sheet(isPresented: $showingAdd) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add a Book").font(.title2.bold())
                TextField("Title", text: $newTitle)
                TextField("Author", text: $newAuthor)
                HStack {
                    Button("Cancel") { showingAdd = false }
                    Spacer()
                    Button("Save") { addBook() }
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  newAuthor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 420)
        }
    }

    @MainActor private func openStore() {
        guard store == nil else { return }
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
                .appendingPathComponent("ReadingCompanion", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let identity = root.appendingPathComponent("local-owner.txt")
            let owner: UUID
            if FileManager.default.fileExists(atPath: identity.path) {
                guard let saved = UUID(uuidString: try String(contentsOf: identity, encoding: .utf8)) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                owner = saved
            } else {
                owner = UUID()
                try owner.uuidString.write(to: identity, atomically: true, encoding: .utf8)
            }
            store = try LocalStore(path: root.appendingPathComponent(owner.uuidString + ".sqlite").path,
                                   ownerID: owner)
            refresh()
        } catch {
            errorMessage = "Unable to open your library. Existing data has not been deleted: \(error.localizedDescription)"
        }
    }

    @MainActor private func refresh() {
        guard let store else { return }
        do {
            books = try store.library(query: search, view: libraryView, sort: librarySort, limit: 500)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load books: \(error.localizedDescription)"
        }
    }

    @MainActor private func addBook() {
        guard let store else { return }
        do {
            _ = try store.add(work: WorkCandidate(provider: "manual", reference: UUID().uuidString,
                                                   title: newTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                                   author: newAuthor.trimmingCharacters(in: .whitespacesAndNewlines)),
                              choice: .addAnyway)
            newTitle = ""
            newAuthor = ""
            showingAdd = false
            refresh()
        } catch {
            errorMessage = "Unable to add book: \(error.localizedDescription)"
        }
    }
}


private struct MacJournalView: View {
    @State private var entries: [JournalInboxItem] = []
    @State private var selectedEntry: JournalInboxItem?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Journal").font(.title2.bold())
            Text("Finished books and their journal entries, loaded from your local Mac library.")
                .foregroundStyle(.secondary)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            } else if entries.isEmpty {
                ContentUnavailableView("No journal entries yet", systemImage: "book.closed",
                                       description: Text("Finish a book to create a journal entry."))
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(entries, id: \.entry.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.book.title).font(.headline)
                            Text(item.book.author).foregroundStyle(.secondary)
                            if let summary = item.entry.summary, !summary.isEmpty {
                                Text(summary).lineLimit(4)
                            }
                            HStack(spacing: 12) {
                                if let pages = item.entry.pageCount {
                                    Label("\(pages) pages", systemImage: "book.pages")
                                }
                                Text("Review: \(item.entry.bookReviewState.rawValue)")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button("View details") { selectedEntry = item }
                            .buttonStyle(.link)
                        Divider()
                    }
                }
            }
            Text("Entries with a saved reading format can be edited on Mac.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .task { loadJournal() }
        .sheet(item: $selectedEntry, onDismiss: { loadJournal() }) { item in
            MacJournalEditor(item: item)
        }
    }

    @MainActor private func loadJournal() {
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
                .appendingPathComponent("ReadingCompanion", isDirectory: true)
            let identity = root.appendingPathComponent("local-owner.txt")
            guard FileManager.default.fileExists(atPath: identity.path),
                  let owner = UUID(uuidString: try String(contentsOf: identity, encoding: .utf8)) else {
                entries = []
                return
            }
            let store = try LocalStore(path: root.appendingPathComponent(owner.uuidString + ".sqlite").path,
                                       ownerID: owner)
            entries = try store.journalInbox()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load journal: \(error.localizedDescription)"
        }
    }
}

private struct MacJournalEditor: View {
    @Environment(\.dismiss) private var dismiss
    let item: JournalInboxItem
    @State private var summary: String
    @State private var formatText: String
    @State private var startDateText: String
    @State private var finishDateText: String
    @State private var ratingSelection: Int
    @State private var pages: String
    @State private var errorMessage: String?

    init(item: JournalInboxItem) {
        self.item = item
        _summary = State(initialValue: item.entry.summary ?? "")
        _formatText = State(initialValue: item.reading.journalFormat?.rawValue ?? "")
        _pages = State(initialValue: item.entry.pageCount.map(String.init) ?? "")
        _startDateText = State(initialValue: item.reading.startDate?.isoString ?? "")
        _finishDateText = State(initialValue: item.reading.finishDate?.isoString ?? "")
        let initialRating: Int
        switch item.reading.rating {
        case .unknown: initialRating = -1
        case .noRating: initialRating = 0
        case .stars(let stars): initialRating = stars
        }
        _ratingSelection = State(initialValue: initialRating)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(item.book.title).font(.title2.bold())
                Spacer()
                Button("Close") { dismiss() }
            }
            Text(item.book.author).foregroundStyle(.secondary)
            LabeledContent("Review status", value: item.entry.bookReviewState.rawValue)
            Picker("Rating", selection: $ratingSelection) {
                Text("Not set").tag(-1)
                Text("No rating").tag(0)
                ForEach(1...5, id: \.self) { stars in
                    Text("\(stars) stars").tag(stars)
                }
            }
            Picker("Reading format", selection: $formatText) {
                Text("Select a format").tag("")
                ForEach(JournalFormat.allCases, id: \.rawValue) { format in
                    Text(format.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .tag(format.rawValue)
                }
            }
            TextField("Pages (optional)", text: $pages)
            TextField("Start date (YYYY-MM-DD, optional)", text: $startDateText)
            TextField("Finish date (YYYY-MM-DD, optional)", text: $finishDateText)
            Text("Summary").font(.headline)
            TextEditor(text: $summary).frame(minHeight: 180)
            if !formatText.isEmpty && JournalFormat(rawValue: formatText) == nil {
                Text("Unsupported reading format. Use a valid format identifier.")
                    .foregroundStyle(.red)
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save Changes") { save() }
                    .disabled(JournalFormat(rawValue: formatText) == nil ||
                              summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              (!pages.isEmpty && (Int(pages) ?? 0) <= 0) ||
                              !validDateText(startDateText) || !validDateText(finishDateText))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 440)
    }

    private func parsedDate(_ text: String) -> ReadingDate? {
        if text.isEmpty { return nil }
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        return try? ReadingDate(year: year, month: month, day: day)
    }

    private func validDateText(_ text: String) -> Bool {
        text.isEmpty || parsedDate(text) != nil
    }

    @MainActor private func save() {
        guard let format = JournalFormat(rawValue: formatText) else { return }
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
                .appendingPathComponent("ReadingCompanion", isDirectory: true)
            let identity = root.appendingPathComponent("local-owner.txt")
            guard let owner = UUID(uuidString: try String(contentsOf: identity, encoding: .utf8)) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let store = try LocalStore(path: root.appendingPathComponent(owner.uuidString + ".sqlite").path,
                                       ownerID: owner)
            let rating: Rating
            switch ratingSelection {
            case -1: rating = .unknown
            case 0: rating = .noRating
            default: rating = .stars(ratingSelection)
            }
            let draft = BookReviewDraft(summary: summary, pageCount: pages.isEmpty ? nil : Int(pages),
                                        rating: rating, format: format,
                                        start: parsedDate(startDateText), finish: parsedDate(finishDateText))
            try store.saveBookReview(readingID: item.reading.id, draft: draft)
            dismiss()
        } catch {
            errorMessage = "Unable to save review: \(error.localizedDescription)"
        }
    }
}

 
/// Read-only series browser backed by the same device-local database as Home and Journal.
private struct MacSeriesView: View {
    @State private var series: [SeriesDetail] = []
    @State private var showingCreate = false
    @State private var confirmingSeriesDeletion = false
    @State private var entryToDelete: SeriesEntry?
    @State private var showingEditSeries = false
    @State private var editSeriesName = ""
    @State private var editSeriesAuthor = ""
    @State private var editingEntry: SeriesEntry?
    @State private var editVolumeTitle = ""
    @State private var editVolumePosition = ""
    @State private var editVolumeKind: SeriesEntryKind = .main
    @State private var showingAddVolume = false
    @State private var linkingEntry: SeriesEntry?
    @State private var linkCandidates: [CatalogRecord] = []
    @State private var chosenBookID: UUID?
    @State private var volumeTitle = ""
    @State private var volumePosition = ""
    @State private var volumeKind: SeriesEntryKind = .main
    @State private var newSeriesName = ""
    @State private var newSeriesAuthor = ""
    @State private var query = ""
    @State private var filter: SeriesFilter = .all
    @State private var sort: SeriesSort = .recentlyUpdated
    @State private var selectedSeries: SeriesDetail?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Series").font(.title2.bold())
                Spacer()
                Button("Add Series", systemImage: "plus") { showingCreate = true }
            }
            TextField("Search series or book titles", text: $query)
                .textFieldStyle(.roundedBorder)
                .onChange(of: query) { _, _ in refresh() }
            HStack {
                Picker("Status", selection: $filter) {
                    ForEach(SeriesFilter.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .onChange(of: filter) { _, _ in refresh() }
                Picker("Sort", selection: $sort) {
                    ForEach(SeriesSort.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .onChange(of: sort) { _, _ in refresh() }
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            } else if series.isEmpty {
                ContentUnavailableView("No series found", systemImage: "books.vertical",
                                       description: Text("Series saved in your local library will appear here."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(series, id: \.series.id) { detail in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(detail.series.name).font(.headline)
                                    if let author = detail.series.author {
                                        Text(author).foregroundStyle(.secondary)
                                    }
                                    Text("\(detail.readConfirmed) of \(detail.confirmedTotal) confirmed books read")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(detail.series.effectiveStatus.rawValue.capitalized)
                                    .foregroundStyle(.secondary)
                                Button("View Books") { selectedSeries = detail }
                            }
                            Divider()
                        }
                    }
                }
            }
            Text("Series are read from this Mac only; iPhone sync is not yet available.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .task { refresh() }
        .confirmationDialog("Delete this series?", isPresented: $confirmingSeriesDeletion,
                            titleVisibility: .visible) {
            Button("Delete Series", role: .destructive) { deleteSelectedSeries() }
        } message: {
            Text("This removes the series and its volumes, but does not delete books or reading records in your library.")
        }
        .confirmationDialog("Delete this volume?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete Volume", role: .destructive) {
                if let entry = entryToDelete { deleteVolume(entry) }
            }
        } message: {
            Text("The volume is removed from this series. Its linked library book and reading records remain untouched.")
        }
        .sheet(isPresented: $showingCreate) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add a Series").font(.title2.bold())
                TextField("Series name", text: $newSeriesName)
                TextField("Author (optional)", text: $newSeriesAuthor)
                Text("Add volumes using View Books after creating the series.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Cancel") { showingCreate = false }
                    Spacer()
                    Button("Create Series") { createSeries() }
                        .disabled(newSeriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 440)
        }
        .sheet(isPresented: Binding(
            get: { linkingEntry != nil },
            set: { if !$0 { linkingEntry = nil } }
        )) {
            if let entry = linkingEntry {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Link a Library Book").font(.title2.bold())
                    Text(entry.title).foregroundStyle(.secondary)
                    Picker("Library book", selection: $chosenBookID) {
                        Text("No linked book").tag(UUID?.none)
                        ForEach(linkCandidates, id: \.book.id) { candidate in
                            Text("\(candidate.book.title) — \(candidate.book.author)")
                                .tag(Optional(candidate.book.id))
                        }
                    }
                    Text("Read progress comes from the linked book's recorded reading status.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Cancel") { linkingEntry = nil }
                        Spacer()
                        Button("Save Link") { saveLink(entry) }
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(24)
                .frame(width: 500)
            }
        }
        .sheet(isPresented: $showingEditSeries) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Series").font(.title2.bold())
                TextField("Series name", text: $editSeriesName)
                TextField("Author (optional)", text: $editSeriesAuthor)
                HStack {
                    Button("Cancel") { showingEditSeries = false }
                    Spacer()
                    Button("Save Changes") { saveSeriesEdits() }
                        .disabled(editSeriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 440)
        }
        .sheet(isPresented: Binding(
            get: { editingEntry != nil },
            set: { if !$0 { editingEntry = nil } }
        )) {
            if let entry = editingEntry {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Edit Volume").font(.title2.bold())
                    TextField("Volume title", text: $editVolumeTitle)
                    TextField("Position (e.g. 1, 1.5)", text: $editVolumePosition)
                    Picker("Type", selection: $editVolumeKind) {
                        Text("Main volume").tag(SeriesEntryKind.main)
                        Text("Related / novella").tag(SeriesEntryKind.related)
                        Text("Companion").tag(SeriesEntryKind.companion)
                    }
                    HStack {
                        Button("Cancel") { editingEntry = nil }
                        Spacer()
                        Button("Save Changes") { saveVolumeEdits(entry) }
                            .disabled(editVolumeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                      validEditPosition == nil)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(24)
                .frame(width: 460)
            }
        }
        .sheet(isPresented: $showingAddVolume) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add a Volume").font(.title2.bold())
                TextField("Volume title", text: $volumeTitle)
                TextField("Position (e.g. 1, 1.5)", text: $volumePosition)
                Picker("Type", selection: $volumeKind) {
                    Text("Main volume").tag(SeriesEntryKind.main)
                    Text("Related / novella").tag(SeriesEntryKind.related)
                    Text("Companion").tag(SeriesEntryKind.companion)
                }
                Text("The volume is added to this series; it is not automatically linked to a library book.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Cancel") { showingAddVolume = false }
                    Spacer()
                    Button("Add Volume") { addVolume() }
                        .disabled(volumeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  validVolumePosition == nil)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 460)
        }
        .sheet(isPresented: Binding(
            get: { selectedSeries != nil },
            set: { if !$0 { selectedSeries = nil } }
        )) {
            if let detail = selectedSeries {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(detail.series.name).font(.title2.bold())
                    Spacer()
                    Button("Edit Series") {
                        editSeriesName = detail.series.name
                        editSeriesAuthor = detail.series.author ?? ""
                        showingEditSeries = true
                    }
                    Button("Add Volume", systemImage: "plus") {
                        volumeTitle = ""
                        volumePosition = ""
                        volumeKind = .main
                        showingAddVolume = true
                    }
                    Button("Delete Series", role: .destructive) {
                        confirmingSeriesDeletion = true
                    }
                    Button("Close") { selectedSeries = nil }
                }
                Text("\(detail.readConfirmed) of \(detail.confirmedTotal) confirmed books read")
                    .foregroundStyle(.secondary)
                if detail.entries.isEmpty {
                    ContentUnavailableView("No books in this series", systemImage: "book.closed")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(detail.entries) { entry in
                                HStack {
                                    Text(NSDecimalNumber(decimal: entry.position).stringValue)
                                        .monospacedDigit().foregroundStyle(.secondary)
                                    VStack(alignment: .leading) {
                                        Text(entry.title)
                                        Text(entry.kind.rawValue.capitalized)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Delete", role: .destructive) {
                                        entryToDelete = entry
                                    }
                                    .buttonStyle(.link)
                                    Button("Edit") {
                                        editVolumeTitle = entry.title
                                        editVolumePosition = NSDecimalNumber(decimal: entry.position).stringValue
                                        editVolumeKind = entry.kind
                                        editingEntry = entry
                                    }
                                    .buttonStyle(.link)
                                    Button(entry.bookID == nil ? "Link Book" : "Change Link") {
                                        beginLink(entry)
                                    }
                                    .buttonStyle(.link)
                                    if entry.isRead {
                                        Label("Read", systemImage: "checkmark.circle.fill")
                                    }
                                }
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(minWidth: 540, minHeight: 420)
            }
        }
    }

    @MainActor private func deleteSelectedSeries() {
        guard let detail = selectedSeries else { return }
        do {
            try existingSeriesStore().deleteSeries(id: detail.series.id)
            selectedSeries = nil
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = "Unable to delete series: \(error.localizedDescription)"
        }
    }

    @MainActor private func deleteVolume(_ entry: SeriesEntry) {
        guard let detail = selectedSeries else { return }
        do {
            let store = try existingSeriesStore()
            try store.deleteSeriesEntry(id: entry.id, seriesID: detail.series.id)
            selectedSeries = try store.seriesDetail(id: detail.series.id)
            entryToDelete = nil
            errorMessage = nil
            refresh()
        } catch {
            entryToDelete = nil
            errorMessage = "Unable to delete volume: \(error.localizedDescription)"
        }
    }

    private var validEditPosition: Decimal? {
        let raw = editVolumePosition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let number = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")),
              number >= 0 else { return nil }
        return number
    }

    @MainActor private func saveSeriesEdits() {
        guard let detail = selectedSeries else { return }
        do {
            let store = try existingSeriesStore()
            let name = editSeriesName.trimmingCharacters(in: .whitespacesAndNewlines)
            let author = editSeriesAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
            var record = detail.series
            record.name = name
            record.author = author.isEmpty ? nil : author
            record.updatedAt = Date()
            try store.saveSeries(record, entries: detail.entries)
            selectedSeries = try store.seriesDetail(id: record.id)
            showingEditSeries = false
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = "Unable to update series: \(error.localizedDescription)"
            showingEditSeries = false
        }
    }

    @MainActor private func saveVolumeEdits(_ entry: SeriesEntry) {
        guard let detail = selectedSeries, let position = validEditPosition else { return }
        guard !detail.entries.contains(where: {
            $0.id != entry.id && $0.position == position && $0.kind == editVolumeKind
        }) else {
            errorMessage = "A volume with this position and type already exists."
            editingEntry = nil
            return
        }
        do {
            let store = try existingSeriesStore()
            var updated = detail.entries
            guard let index = updated.firstIndex(where: { $0.id == entry.id }) else { return }
            updated[index] = SeriesEntry(id: entry.id, seriesID: entry.seriesID,
                                         bookID: entry.bookID,
                                         title: editVolumeTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                         position: position, kind: editVolumeKind,
                                         publication: entry.publication, release: entry.release,
                                         included: entry.included, includedInTracker: entry.includedInTracker)
            var record = detail.series
            record.updatedAt = Date()
            try store.saveSeries(record, entries: updated)
            selectedSeries = try store.seriesDetail(id: record.id)
            editingEntry = nil
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = "Unable to update volume: \(error.localizedDescription)"
            editingEntry = nil
        }
    }

    @MainActor private func beginLink(_ entry: SeriesEntry) {
        do {
            let store = try existingSeriesStore()
            linkCandidates = try store.library(query: "", view: .all, sort: .title, limit: 500)
            chosenBookID = entry.bookID
            linkingEntry = entry
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load library books: \(error.localizedDescription)"
        }
    }

    @MainActor private func saveLink(_ entry: SeriesEntry) {
        guard let detail = selectedSeries else { return }
        do {
            let store = try existingSeriesStore()
            var updated = detail.entries
            guard let index = updated.firstIndex(where: { $0.id == entry.id }) else { return }
            updated[index] = SeriesEntry(id: entry.id, seriesID: entry.seriesID,
                                         bookID: chosenBookID, title: entry.title,
                                         position: entry.position, kind: entry.kind,
                                         publication: entry.publication, release: entry.release,
                                         included: entry.included, includedInTracker: entry.includedInTracker)
            try store.saveSeries(detail.series, entries: updated)
            selectedSeries = try store.seriesDetail(id: detail.series.id)
            linkingEntry = nil
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = "Unable to save book link: \(error.localizedDescription)"
            linkingEntry = nil
        }
    }

    private func existingSeriesStore() throws -> LocalStore {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
            .appendingPathComponent("ReadingCompanion", isDirectory: true)
        let identity = root.appendingPathComponent("local-owner.txt")
        guard FileManager.default.fileExists(atPath: identity.path),
              let owner = UUID(uuidString: try String(contentsOf: identity, encoding: .utf8)) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try LocalStore(path: root.appendingPathComponent(owner.uuidString + ".sqlite").path,
                              ownerID: owner)
    }

    private var validVolumePosition: Decimal? {
        let raw = volumePosition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let number = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")),
              number >= 0 else { return nil }
        return number
    }

    @MainActor private func addVolume() {
        guard let detail = selectedSeries, let position = validVolumePosition else { return }
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
                .appendingPathComponent("ReadingCompanion", isDirectory: true)
            let identity = root.appendingPathComponent("local-owner.txt")
            guard let owner = UUID(uuidString: try String(contentsOf: identity, encoding: .utf8)) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let store = try LocalStore(path: root.appendingPathComponent(owner.uuidString + ".sqlite").path,
                                       ownerID: owner)
            guard !detail.entries.contains(where: { $0.position == position && $0.kind == volumeKind }) else {
                errorMessage = "A volume with this position and type already exists."
                showingAddVolume = false
                return
            }
            let entry = SeriesEntry(seriesID: detail.series.id, bookID: nil,
                                    title: volumeTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                    position: position, kind: volumeKind,
                                    publication: .unknown, release: .unknown)
            try store.saveSeries(detail.series, entries: detail.entries + [entry])
            selectedSeries = try store.seriesDetail(id: detail.series.id)
            showingAddVolume = false
            volumeTitle = ""
            volumePosition = ""
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = "Unable to add volume: \(error.localizedDescription)"
            showingAddVolume = false
        }
    }

    @MainActor private func createSeries() {
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
                .appendingPathComponent("ReadingCompanion", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let identity = root.appendingPathComponent("local-owner.txt")
            let owner: UUID
            if FileManager.default.fileExists(atPath: identity.path) {
                guard let saved = UUID(uuidString: try String(contentsOf: identity, encoding: .utf8)) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                owner = saved
            } else {
                owner = UUID()
                try owner.uuidString.write(to: identity, atomically: true, encoding: .utf8)
            }
            let store = try LocalStore(path: root.appendingPathComponent(owner.uuidString + ".sqlite").path,
                                       ownerID: owner)
            let name = newSeriesName.trimmingCharacters(in: .whitespacesAndNewlines)
            let author = newSeriesAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
            let record = ReadingSeries(ownerID: owner, name: name, author: author.isEmpty ? nil : author)
            try store.saveSeries(record, entries: [])
            newSeriesName = ""
            newSeriesAuthor = ""
            showingCreate = false
            refresh()
        } catch {
            errorMessage = "Unable to create series: \(error.localizedDescription)"
        }
    }

    @MainActor private func refresh() {
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
                .appendingPathComponent("ReadingCompanion", isDirectory: true)
            let identity = root.appendingPathComponent("local-owner.txt")
            guard FileManager.default.fileExists(atPath: identity.path),
                  let owner = UUID(uuidString: try String(contentsOf: identity, encoding: .utf8)) else {
                series = []
                errorMessage = nil
                return
            }
            let store = try LocalStore(path: root.appendingPathComponent(owner.uuidString + ".sqlite").path,
                                       ownerID: owner)
            series = try store.series(query: query, filter: filter, sort: sort)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load series: \(error.localizedDescription)"
        }
    }
}
