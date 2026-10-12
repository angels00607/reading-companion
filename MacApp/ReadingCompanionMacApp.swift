import SwiftUI
import ReadingUI
import ReadingData
import ReadingDomain

@main
struct ReadingCompanionMacApp: App {
    var body: some Scene {
        WindowGroup("Reading Companion") {
            FoundationShell(homeContent: AnyView(MacLibraryView()))
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
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
                    .accessibilityIdentifier("macLibrary.error")
            }
            if books.isEmpty {
                ContentUnavailableView("No books found", systemImage: "books.vertical",
                                       description: Text("Add a book to begin your Mac library."))
            } else {
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
            books = try store.library(query: search, limit: 500)
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
