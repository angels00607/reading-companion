import SwiftUI
import ReadingUI
import ReadingData
import ReadingDomain

@main
struct ReadingCompanionMacApp: App {
    var body: some Scene {
        WindowGroup("Reading Companion") {
            FoundationShell(homeContent: AnyView(MacLibraryView()),
                            journalContent: AnyView(MacJournalView()))
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 1100, height: 760)
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
    @State private var pages: String
    @State private var errorMessage: String?

    init(item: JournalInboxItem) {
        self.item = item
        _summary = State(initialValue: item.entry.summary ?? "")
        _pages = State(initialValue: item.entry.pageCount.map(String.init) ?? "")
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
            TextField("Pages (optional)", text: $pages)
            Text("Summary").font(.headline)
            TextEditor(text: $summary).frame(minHeight: 180)
            if item.reading.journalFormat == nil {
                Text("Set a reading format on iPhone before editing this entry.")
                    .foregroundStyle(.secondary)
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save Changes") { save() }
                    .disabled(item.reading.journalFormat == nil ||
                              summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              (!pages.isEmpty && (Int(pages) ?? 0) <= 0))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 440)
    }

    @MainActor private func save() {
        guard let format = item.reading.journalFormat else { return }
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
            let draft = BookReviewDraft(summary: summary, pageCount: pages.isEmpty ? nil : Int(pages),
                                        rating: item.reading.rating, format: format,
                                        start: item.reading.startDate, finish: item.reading.finishDate)
            try store.saveBookReview(readingID: item.reading.id, draft: draft)
            dismiss()
        } catch {
            errorMessage = "Unable to save review: \(error.localizedDescription)"
        }
    }
}
