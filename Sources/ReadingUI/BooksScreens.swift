import SwiftUI
import ReadingDomain
#if os(iOS)
import PhotosUI
import UIKit
#endif

public struct BooksHome: View {
    @EnvironmentObject private var model: BooksModel
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 320
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink { GlobalSearchScreen() } label: { Label("Search / Add Book", systemImage: "magnifyingglass").frame(minHeight: 44) }.accessibilityIdentifier("books.search")
            NavigationLink { MyBooksScreen() } label: { Label("My Books", systemImage: "books.vertical").frame(minHeight: 44) }.accessibilityIdentifier("books.library")
            Text("Currently Reading").font(DesignTokens.functionalFont(size: 22, relativeTo: .title2, weight: .semiBold)).accessibilityAddTraits(.isHeader)
            let active = (try? model.repository.library(query: "", view: .all, sort: .recentlyAdded, filters: activeFilter, limit: 200, offset: 0)) ?? []
            if active.isEmpty { StatePresentation(kind: .empty, title: "No active reading", message: "Add a book or start one from My Books.") }
            else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(active) { record in
                            ScrollView {
                              VStack(alignment: .leading, spacing: 12) {
                                BooksRow(record: record)
                                if let reading = record.active { ReadingProgressBar(displayProgress(reading.progress)); NavigationLink { BookPageScreen(bookID: record.id) } label: { Text("Update Progress").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) } }
                              }
                            }.frame(width: 270, height: cardHeight, alignment: .top)
                        }
                    }
                }
            }
            BooksErrorMessage()
        }
    }
    private var activeFilter: LibraryFilters { var f = LibraryFilters(); f.status = .currentlyReading; return f }
}

struct BooksRow: View {
    @EnvironmentObject var model: BooksModel
    let record: CatalogRecord
    var body: some View {
        NavigationLink { BookPageScreen(bookID: record.id) } label: {
            BookRow(book: PreviewBook(id: record.id.uuidString, title: record.book.title, author: record.book.author,
                detail: record.statusLabel, coverURL: model.coverURL(record.coverReference ?? record.editions.first?.coverReference)))
        }.buttonStyle(.plain).accessibilityIdentifier("books.row." + record.id.uuidString)
    }
}
func displayProgress(_ value: ReadingProgress) -> ReadingProgressValue {
    value.mode == .page ? .pages(current: value.currentPage, total: value.totalPages) : .percentage(value.percentage)
}

struct GlobalSearchScreen: View {
    @EnvironmentObject var model: BooksModel
    @State private var query = ""
    @State private var external: [WorkCandidate] = []
    @State private var local: [CatalogRecord] = []
    @State private var loading = false
    @State private var unavailable = false
    @State private var localLimit = 50
    var body: some View {
        BooksScreen("Global Search") {
            BooksField(label: "Search title or author", value: $query)
            NavigationLink { MyBooksScreen() } label: {
                BooksNavigationLabel("My Books", symbol: "books.vertical", detail: "Browse your saved books")
            }.buttonStyle(.plain)
            NavigationLink { ManualAddScreen() } label: {
                BooksNavigationLabel("Add a book manually", symbol: "plus", detail: "When search does not find the right book", emphasized: false)
            }.buttonStyle(.plain).accessibilityIdentifier("books.manual")
            BooksSectionHeader("Your library", detail: "Matches already saved on this device")
            ForEach(local) { BooksRow(record: $0) }
            if local.count == localLimit { AppButton("More local results", kind: .secondary) { localLimit += 50; loadLocal() } }
            if !query.isEmpty && local.isEmpty { Text("No local matches") }
            BooksSectionHeader("Book catalogue", detail: "More results to add to your library")
            if loading { SkeletonRow() }
            if unavailable { OfflineBanner(); Text("Catalogue search is unavailable. Your library and manual entry remain usable.") }
            ForEach(external) { work in
                NavigationLink { EditionSelectionScreen(work: work) } label: {
                    BookRow(book: PreviewBook(id: work.id, title: work.title ?? "Title unknown", author: work.author ?? "Author unknown", detail: "Catalogue result", coverURL: model.coverURL(work.coverReference)))
                }.buttonStyle(.plain).accessibilityIdentifier("books.external." + work.reference)
            }
            BooksErrorMessage()
        }.task(id: query) {
            loadLocal(); external = []; unavailable = false
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            loading = true
            do {
                try await Task.sleep(for: .milliseconds(400))
                let results = try await model.provider.searchWorks(query: query)
                try Task.checkCancellation(); external = results; loading = false
            } catch is CancellationError { }
            catch { if !Task.isCancelled { unavailable = true; loading = false } }
        }.onChange(of: model.version) { loadLocal() }
    }
    private func loadLocal() { do { local = try model.repository.library(query: query, view: .all, sort: .title, filters: LibraryFilters(), limit: localLimit, offset: 0) } catch { model.error = "Could not read the local library." } }
}

struct EditionSelectionScreen: View {
    @EnvironmentObject var model: BooksModel
    @Environment(\.colorScheme) private var scheme
    let work: WorkCandidate
    @State private var editions: [EditionCandidate] = []
    @State private var loading = true
    @State private var unavailable = false
    var body: some View {
        BooksScreen("Choose Edition") {
            Text(work.title ?? "Title unknown").font(DesignTokens.functionalFont(size: 22, relativeTo: .title2, weight: .semiBold))
            Text("English editions appear first. Languages are shown only from actual catalogue records.")
            if loading { SkeletonRow() }
            if unavailable { StatePresentation(kind: .offline, title: "Editions unavailable", message: "Add without edition details or use Manual Add.") }
            ForEach(editions) { edition in
                NavigationLink { AddBookScreen(work: work, edition: edition) } label: {
                    EditionChoiceLabel(edition: edition, fallbackTitle: work.title ?? "Title unknown")
                }.buttonStyle(.plain).accessibilityIdentifier("books.edition." + edition.reference)
            }
            if !loading { NavigationLink { AddBookScreen(work: work, edition: nil) } label: { Text("Add without an edition").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) } }
            Text("Up to 200 available edition records are loaded. An absent language or edition is not evidence that it does not exist.").font(DesignTokens.functionalFont(size: 13))
        }.task {
            do { editions = try await model.provider.editions(for: work) } catch { unavailable = true }
            loading = false
        }
    }
}

struct AddBookScreen: View {
    @EnvironmentObject var model: BooksModel
    @Environment(\.manualBookExtras) private var extras
    let work: WorkCandidate
    let edition: EditionCandidate?
    @State private var title: String
    @State private var author: String
    @State private var state = "To Read"
    @State private var mode = ProgressMode.page
    @State private var startDate = BooksModel.today.isoString
    @State private var finishDate = ""
    @State private var rating = "No rating"
    @State private var duplicates: [CatalogRecord] = []
    @State private var added: UUID?
    @State private var saving = false
    init(work: WorkCandidate, edition: EditionCandidate?) {
        self.work = work; self.edition = edition; _title = State(initialValue: work.title ?? ""); _author = State(initialValue: work.author ?? "")
    }
    var body: some View {
        BooksScreen("Add Book") {
            BooksField(label: "Title", value: $title); BooksField(label: "Author", value: $author)
            Picker("Add as", selection: $state) { ForEach(["To Read","Currently Reading","Already Read"], id: \.self) { Text($0).tag($0) } }.frame(minHeight: 44)
            if state == "Currently Reading" {
                Picker("Progress mode", selection: $mode) { Text("Page").tag(ProgressMode.page); Text("Percentage").tag(ProgressMode.percentage) }.frame(minHeight: 44)
                BooksField(label: "Start date (YYYY-MM-DD or unknown)", value: $startDate)
            }
            if state == "Already Read" {
                BooksField(label: "Finish date (YYYY-MM-DD or unknown)", value: $finishDate)
                Picker("Rating", selection: $rating) { ForEach(["No rating","1","2","3","4","5"], id: \.self) { Text($0).tag($0) } }.frame(minHeight: 44)
                Text("Adding as Already Read explicitly records completion. Unknown dates and progress remain unknown.")
            }
            Text("Format is not inferred or requested when adding a book.").font(DesignTokens.functionalFont(size: 13))
            if let added { NavigationLink { BookPageScreen(bookID: added) } label: { Text("Open Book").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }.accessibilityIdentifier("books.openAdded") }
            else {
                AppButton(state == "Already Read" ? "Confirm Already Read" : "Add Book") { add(.review) }.disabled(saving).accessibilityIdentifier("books.add")
                if !duplicates.isEmpty {
                    Text("Possible duplicate — choose the existing book or explicitly Add Anyway.")
                    ForEach(duplicates) { record in AppButton("Use existing: " + record.book.title, kind: .secondary) { add(.reuse(record.id)) } }
                    AppButton("Add Anyway", kind: .secondary) { add(.addAnyway) }
                }
            }
            BooksErrorMessage()
        }
    }
    private func add(_ choice: DuplicateChoice) {
        guard added == nil && !saving else { return }
        saving = true; defer { saving = false }
        var candidate = work; candidate.title = title; candidate.author = author
        do {
            // Validate all input before creating anything.
            let date = try BooksModel.parseDate(state == "Already Read" ? finishDate : startDate)
            let selectedRating: Rating = rating == "No rating" ? .noRating : try .validatedStars(Int(rating)!)
            let intent: LibraryAddition = state == "To Read" ? .toRead : state == "Already Read" ? .alreadyRead(date: date, rating: selectedRating) : .currentlyReading(mode: mode, date: date)
            var manualValues = extras
            if title != work.title { manualValues[.title] = title }
            if author != work.author { manualValues[.author] = author }
            let id = try model.repository.addWithIntent(work: candidate, edition: edition, choice: choice, intent: intent, manualValues: manualValues)
            added = id; model.error = nil; model.version += 1
        } catch BooksError.duplicateNeedsReview(let ids) { duplicates = ids.compactMap { try? model.repository.record(id: $0) } }
        catch { model.error = "Could not add this book. Existing local data has not changed. \(error.localizedDescription)" }
    }
}

struct ManualAddScreen: View {
    @EnvironmentObject var model: BooksModel
    @State private var title = ""
    @State private var author = ""
    @State private var pages = ""
    @State private var genre = ""
    @State private var series = ""
    @State private var isbn = ""
    @State private var cover = ""
    @State private var candidate: WorkCandidate?
    @State private var edition: EditionCandidate?
    @State private var showAdd = false
    var body: some View {
        BooksScreen("Manual Add") {
            BooksFormSection("Required information") {
                BooksField(label: "Title", value: $title)
                BooksField(label: "Author", value: $author)
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    BooksField(label: "Total pages", value: $pages); BooksField(label: "Primary Genre", value: $genre)
                    BooksField(label: "Series name", value: $series); BooksField(label: "ISBN", value: $isbn)
                    CoverEditor(reference: $cover)
                }.padding(.vertical, 12)
            } label: {
                BooksDisclosureLabel("Optional book information", detail: "Edition, genre, series and cover")
            }.frame(minHeight: 44)
            AppButton("Continue") {
                _ = model.perform {
                    let t = try BooksRules.validatedText(title), a = try BooksRules.validatedText(author)
                    let total = try BooksModel.optionalPages(pages)
                    candidate = WorkCandidate(provider: "manual", reference: UUID().uuidString, title: t, author: a, coverReference: cover.isEmpty ? nil : cover)
                    if !cover.isEmpty, model.coverURL(cover) == nil { throw BooksError.invalidMetadata }
                    edition = EditionCandidate(provider: "manual", reference: UUID().uuidString, title: t, isbn10: isbn.count == 10 ? isbn : nil, isbn13: isbn.isEmpty || isbn.count == 10 ? nil : isbn, pageCount: total)
                    showAdd = true
                }
            }
            BooksErrorMessage()
        }.navigationDestination(isPresented: $showAdd) {
            if let candidate { ManualAddCompletion(work: candidate, edition: edition, genre: genre, series: series) }
        }
    }
}
private struct ManualAddCompletion: View {
    let work: WorkCandidate; let edition: EditionCandidate?; let genre: String; let series: String
    var body: some View { AddBookScreen(work: work, edition: edition).environment(\.manualBookExtras, [BookField.genreSuggestion: genre, .series: series]) }
}
private struct ManualBookExtrasKey: EnvironmentKey { static let defaultValue: [BookField: String] = [:] }
extension EnvironmentValues { var manualBookExtras: [BookField: String] { get { self[ManualBookExtrasKey.self] } set { self[ManualBookExtrasKey.self] = newValue } } }

struct MyBooksScreen: View {
    @EnvironmentObject var model: BooksModel
    @State private var view = LibraryView.all
    @State private var sort = LibrarySort.recentlyAdded
    @State private var query = ""
    @State private var status = "All"
    @State private var year = ""
    @State private var genre = ""
    @State private var rating = ""
    @State private var format = "All"
    @State private var series = "All"
    @State private var records: [CatalogRecord] = []
    @State private var limit = 50
    var body: some View {
        BooksScreen("My Books") {
            AppSegmentedControl(options: LibraryView.allCases.map { ($0,$0.rawValue) }, selection: $view)
            BooksField(label: "Search your books", value: $query)
            DisclosureGroup {
                Picker("Sort", selection: $sort) { ForEach(allowedSorts, id: \.self) { Text($0.rawValue).tag($0) } }.frame(minHeight: 44)
                if view == .all { Picker("Reading status", selection: $status) { ForEach(["All","Currently Reading","Read","DNF"], id: \.self) { Text($0).tag($0) } }.frame(minHeight: 44) }
                if view == .read {
                    BooksField(label: "Finish year", value: $year); BooksField(label: "Rating (1–5)", value: $rating); BooksField(label: "Primary Genre", value: $genre)
                    Picker("Format", selection: $format) { Text("All").tag("All"); ForEach(JournalFormat.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0.rawValue) } }.frame(minHeight: 44)
                    Picker("Series", selection: $series) { ForEach(["All","Series","Standalone"], id: \.self) { Text($0).tag($0) } }.frame(minHeight: 44)
                }
            } label: {
                BooksDisclosureLabel("Sort and filters", symbol: "line.3.horizontal.decrease.circle")
            }.frame(minHeight: 44)
            ForEach(records) { BooksRow(record: $0) }
            if records.isEmpty { StatePresentation(kind: .empty, title: "No books here yet", message: "Search or manually add a book. Unknown information can stay unknown.") }
            if records.count == limit { AppButton("Load more", kind: .secondary) { limit += 50; reload() } }
            BooksErrorMessage()
        }.onAppear(perform: reload).onChange(of: model.version) { reload() }.onChange(of: query) { reload() }
            .onChange(of: view) { sort = view == .read ? .recentlyFinished : view == .toRead ? .title : .recentlyAdded; reload() }
            .onChange(of: sort) { reload() }.onChange(of: status) { reload() }.onChange(of: year) { reload() }
            .onChange(of: rating) { reload() }.onChange(of: genre) { reload() }.onChange(of: format) { reload() }.onChange(of: series) { reload() }
    }
    private var allowedSorts: [LibrarySort] {
        switch view {
        case .all: [.recentlyAdded,.title,.titleDescending,.author,.authorDescending,.pages,.pagesDescending]
        case .toRead: [.title,.author,.pages]
        case .read: [.recentlyFinished,.oldest,.title,.author,.rating,.pages]
        }
    }
    private func reload() {
        var f = LibraryFilters()
        if view == .all { f.status = status == "Currently Reading" ? .currentlyReading : status == "Read" ? .read : status == "DNF" ? .dnf : nil }
        if view == .read { f.year = Int(year); f.rating = Int(rating); f.genre = genre.isEmpty ? nil : genre; f.format = JournalFormat(rawValue: format); f.inSeries = series == "All" ? nil : series == "Series" }
        records = (try? model.repository.library(query: query, view: view, sort: sort, filters: f, limit: limit, offset: 0)) ?? []
    }
}

private struct BooksSectionHeader: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let detail: String?
    init(_ title: String, detail: String? = nil) { self.title = title; self.detail = detail }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(DesignTokens.functionalFont(size: 19, relativeTo: .headline, weight: .semiBold))
                .accessibilityAddTraits(.isHeader)
            if let detail { Text(detail).font(DesignTokens.functionalFont(size: 13, relativeTo: .caption)).foregroundStyle(DesignTokens.secondaryText(scheme)) }
        }.padding(.top, DesignTokens.Spacing.small)
    }
}

private struct BooksNavigationLabel: View {
    @Environment(\.colorScheme) private var scheme
    let title: String; let symbol: String; let detail: String; let emphasized: Bool
    init(_ title: String, symbol: String, detail: String, emphasized: Bool = true) {
        self.title = title; self.symbol = symbol; self.detail = detail; self.emphasized = emphasized
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 24).foregroundStyle(DesignTokens.primary(scheme)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DesignTokens.functionalFont(size: 16, relativeTo: .body, weight: .semiBold))
                Text(detail).font(DesignTokens.functionalFont(size: 13, relativeTo: .caption)).foregroundStyle(DesignTokens.secondaryText(scheme))
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").foregroundStyle(DesignTokens.secondaryText(scheme)).accessibilityHidden(true)
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(12)
            .background(emphasized ? DesignTokens.blueSurface(scheme) : DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.buttonRadius))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.buttonRadius).stroke(DesignTokens.border(scheme)))
    }
}

struct BooksDisclosureLabel: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String; let symbol: String; let detail: String?
    init(_ title: String, symbol: String = "info.circle", detail: String? = nil) { self.title = title; self.symbol = symbol; self.detail = detail }
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                labelText
            } else {
                HStack(spacing: 10) {
                    Image(systemName: symbol).foregroundStyle(DesignTokens.primary(scheme)).accessibilityHidden(true)
                    labelText
                }
            }
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 8)
    }
    private var labelText: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DesignTokens.functionalFont(size: 16, relativeTo: .body, weight: .semiBold))
                if let detail { Text(detail).font(DesignTokens.functionalFont(size: 13, relativeTo: .caption)).foregroundStyle(DesignTokens.secondaryText(scheme)) }
            }.fixedSize(horizontal: false, vertical: true)
    }
}

struct BooksFormSection<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String; @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(DesignTokens.functionalFont(size: 18, relativeTo: .headline, weight: .semiBold)).accessibilityAddTraits(.isHeader)
            content
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.cardRadius).stroke(DesignTokens.border(scheme)))
    }
}

private struct EditionChoiceLabel: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    let edition: EditionCandidate; let fallbackTitle: String
    private var metadata: [String] {
        [edition.language.map(languageName) ?? "Language unknown", edition.pageCount.map { "\($0) pages" } ?? "Pages unknown", edition.publisher].compactMap { $0 }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(edition.title ?? fallbackTitle).font(DesignTokens.functionalFont(size: 17, relativeTo: .headline, weight: .semiBold)).fixedSize(horizontal: false, vertical: true)
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) { ForEach(metadata, id: \.self) { Text($0) } }
                } else {
                    Text(metadata.joined(separator: " · ")).fixedSize(horizontal: false, vertical: true)
                }
                if let isbn = edition.isbn13 ?? edition.isbn10 {
                    Text("ISBN " + isbn).font(DesignTokens.functionalFont(size: 12, relativeTo: .caption)).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").foregroundStyle(DesignTokens.secondaryText(scheme)).accessibilityHidden(true)
        }.font(DesignTokens.functionalFont(size: 14, relativeTo: .subheadline)).foregroundStyle(DesignTokens.text(scheme))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(16)
            .background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.cardRadius).stroke(DesignTokens.border(scheme)))
    }
    private func languageName(_ code: String) -> String {
        switch code.lowercased() { case "en", "eng": "English"; case "fr", "fre", "fra": "French"; default: code }
    }
}

struct CoverEditor: View {
    @EnvironmentObject var model: BooksModel
    @Binding var reference: String
    #if os(iOS)
    @State private var photo: PhotosPickerItem?
    #endif
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BooksField(label: "Cover HTTPS URL (optional)", value: $reference)
            #if os(iOS)
            PhotosPicker("Choose cover photo", selection: $photo, matching: .images).frame(minHeight: 44)
                .onChange(of: photo) {
                    Task {
                        guard let data = try? await photo?.loadTransferable(type: Data.self), data.count <= 10_000_000,
                              let image = UIImage(data: data) else { model.error = "Choose a supported image under 10 MB."; return }
                        let ratio = min(1, 1200 / max(image.size.width,image.size.height))
                        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                        let renderer = UIGraphicsImageRenderer(size: size)
                        let png = renderer.pngData { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                        if let saved = model.perform({ try model.saveCover(png) }) { reference = saved }
                    }
                }
            #endif
            AppButton("Remove cover", kind: .tertiary) { reference = "" }
        }
    }
}
