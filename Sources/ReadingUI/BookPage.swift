import SwiftUI
import ReadingDomain

struct BookPageScreen: View {
    @EnvironmentObject var model: BooksModel
    let bookID: UUID
    var showFinishOnAppear = false
    @State private var record: CatalogRecord?
    @State private var action: BookSheet?
    @State private var confirmFinish = false
    @State private var finishDate = BooksModel.today.isoString
    @State private var reviews: [MetadataReview] = []
    @State private var refreshing = false
    @State private var finishAfterProgress = false
    private enum BookSheet: String, Identifiable { case start, progress, history, info; var id: String { rawValue } }
    var body: some View {
        BooksScreen("Book Page") {
            if let record {
                if let feedback = model.feedback { AppToast(feedback) }
                BookCover(title: record.book.title, width: 108, url: model.coverURL(record.coverReference ?? record.editions.first?.coverReference))
                Text(record.book.title).font(DesignTokens.functionalFont(size: 28, relativeTo: .largeTitle, weight: .semiBold)).fixedSize(horizontal: false, vertical: true)
                Text(record.book.author).fixedSize(horizontal: false, vertical: true)
                if let series = record.seriesName { Text(series) }
                StatusChip(record.statusLabel, symbol: record.active != nil ? "book.pages" : "bookmark")
                if let reading = record.active {
                    ReadingProgressBar(displayProgress(reading.progress))
                    AppButton("Update Progress") { action = .progress }.accessibilityIdentifier("books.update")
                    AppButton("Finish Book", kind: .secondary) { confirmFinish = true }.accessibilityIdentifier("books.finish")
                    AppButton("Mark DNF", kind: .tertiary) { _ = model.perform { try model.repository.markDNF(readingID: reading.id, revision: reading.revision) }; reload() }
                    ForEach(reading.progressObservations.filter(\.requiresReview), id: \.id) { observation in
                        DataChangeReview(field: "Progress conflict", current: displayProgress(reading.progress).label, proposed: displayProgress(observation.value).label, source: "Retained observation", accept: {
                            _ = model.perform { try model.repository.resolveProgress(readingID: reading.id, observationID: observation.id, apply: true, revision: reading.revision) }; reload()
                        }, keep: {
                            _ = model.perform { try model.repository.resolveProgress(readingID: reading.id, observationID: observation.id, apply: false, revision: reading.revision) }; reload()
                        }, edit: { action = .progress })
                    }
                } else {
                    if let dnf = record.latest, dnf.status == .dnf {
                        ReadingProgressBar(displayProgress(dnf.progress))
                        Text("DNF retains genuine progress and does not count as completion.")
                        AppButton("Resume Reading") { _ = model.perform { try model.repository.resume(readingID: dnf.id, revision: dnf.revision) }; reload() }
                    }
                    AppButton(record.completedCount > 0 ? "Start Reread" : "Start Reading") { action = .start }.accessibilityIdentifier("books.start")
                }
                if let rating = record.latest?.rating { Text(ratingLabel(rating)) }
                Text("External Book Synopsis").accessibilityAddTraits(.isHeader)
                Text(record.synopsis ?? "No summary available")
                NavigationLink("Reading History") { ReadingHistoryScreen(bookID: bookID) }.frame(minHeight: 44).accessibilityIdentifier("books.history")
                AppButton("Edit Book Info", kind: .secondary) { action = .info }.accessibilityIdentifier("books.info")
                if let source = (try? model.repository.providerWorks(bookID: bookID))?.first(where: { $0.provider == model.provider.key }) {
                    AppButton(refreshing ? "Checking metadata…" : "Check external metadata", kind: .tertiary) {
                        refreshing = true
                        Task {
                            do { let fresh = try await model.provider.refresh(work: source); _ = model.perform { try model.repository.reviewProvider(bookID: bookID, work: fresh) }; reload() }
                            catch { model.error = "External metadata unavailable. Your local data has not changed." }
                            refreshing = false
                        }
                    }.disabled(refreshing)
                }
                ForEach(reviews) { review in
                    DataChangeReview(field: review.field.rawValue.capitalized, current: review.current ?? "Unknown", proposed: review.proposed ?? "Unknown", source: review.source, accept: { _ = model.perform { try model.repository.decide(proposalID: review.id, accept: true) }; reload() }, keep: { _ = model.perform { try model.repository.decide(proposalID: review.id, accept: false) }; reload() }, edit: { action = .info })
                }
            }
            BooksErrorMessage()
        }.onAppear { reload(); if showFinishOnAppear { confirmFinish = true } }.onChange(of: model.version) { reload() }
            .sheet(item: $action, onDismiss: { reload(); if finishAfterProgress { finishAfterProgress = false; confirmFinish = true } }) { sheet in
                NavigationStack {
                    if let record {
                        switch sheet {
                        case .start: StartReadingScreen(record: record)
                        case .progress: if let active = record.active { UpdateProgressScreen(reading: active) { suggests in finishAfterProgress = suggests; action = nil } }
                        case .history: ReadingHistoryScreen(bookID: bookID)
                        case .info: EditBookInfoScreen(record: record)
                        }
                    }
                }
            }
            .sheet(isPresented: $confirmFinish) {
                NavigationStack {
                    BooksScreen("Finish Book") {
                        AppBottomSheet(title: "Confirm completion") {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Reaching the final page or 100% does not finish this reading. Confirm only when you have finished.")
                                BooksField(label: "Finish date (YYYY-MM-DD or unknown)", value: $finishDate)
                                AppButton("Confirm Finish") {
                                    guard let active = record?.active else { return }
                                    if model.perform({ try model.repository.finish(readingID: active.id, confirmed: true, date: BooksModel.parseDate(finishDate), revision: active.revision) }) != nil { confirmFinish = false; reload() }
                                }.accessibilityIdentifier("books.confirmFinish")
                                AppButton("Keep Reading", kind: .secondary) { confirmFinish = false }
                                BooksErrorMessage()
                            }
                        }
                    }
                }
            }
    }
    private func reload() { do { record = try model.repository.record(id: bookID); reviews = try model.repository.proposals(bookID: bookID) } catch { model.error = "Could not load this book." } }
}
func ratingLabel(_ rating: Rating) -> String {
    switch rating { case .unknown: "Rating unknown"; case .noRating: "No rating"; case .stars(let stars): "\(stars) stars" }
}

struct StartReadingScreen: View {
    @EnvironmentObject var model: BooksModel
    @Environment(\.dismiss) var dismiss
    let record: CatalogRecord
    @State private var editionID: UUID?
    @State private var mode = ProgressMode.page
    @State private var startDate = BooksModel.today.isoString
    var body: some View {
        BooksScreen("Start Reading") {
            Picker("Edition", selection: $editionID) {
                Text("Edition unknown").tag(Optional<UUID>.none)
                ForEach(record.editions, id: \.id) { edition in Text((edition.title ?? record.book.title) + " · " + (edition.language ?? "Language unknown")).tag(Optional(edition.id)) }
            }.frame(minHeight: 44)
            Picker("Progress mode", selection: $mode) { Text("Page").tag(ProgressMode.page); Text("Percentage").tag(ProgressMode.percentage) }.frame(minHeight: 44)
            Text("Page starts at 0. Percentage begins unknown. Format remains a separate user-only field.")
            BooksField(label: "Start date (YYYY-MM-DD or unknown)", value: $startDate)
            AppButton("Start Reading") {
                if model.perform({ try model.repository.start(bookID: record.id, editionID: editionID, mode: mode, date: BooksModel.parseDate(startDate)) }) != nil { dismiss() }
            }.accessibilityIdentifier("books.confirmStart")
            BooksErrorMessage()
        }.onAppear { editionID = record.editions.first?.id }
    }
}

struct UpdateProgressScreen: View {
    @EnvironmentObject var model: BooksModel
    let reading: ReadingInstance
    let saved: (Bool) -> Void
    @State private var position = ""
    @State private var total = ""
    @State private var increment = ""
    @State private var feedback: String?
    var body: some View {
        BooksScreen("Update Progress") {
            AppBottomSheet(title: reading.progress.mode == .page ? "Page progress" : "Percentage progress") {
                VStack(alignment: .leading, spacing: 16) {
                    ReadingProgressBar(displayProgress(reading.progress))
                    if reading.progress.mode == .page {
                        BooksField(label: "Current page", value: $position)
                        BooksField(label: "Total pages (optional)", value: $total)
                        DisclosureGroup("Add a page increment") {
                            BooksField(label: "Pages to add", value: $increment)
                            AppButton("Apply page increment", kind: .secondary) {
                                _ = model.perform {
                                    guard let amount = Int(increment) else { throw DomainError.invalidProgress }
                                    let value = try BooksRules.pageIncrement(amount, reading: reading)
                                    position = String(value.currentPage!); feedback = "+\(amount) pages"
                                }
                            }
                        }.frame(minHeight: 44)
                    } else {
                        BooksField(label: "Percentage (0–100)", value: $position)
                        Text("Fractional values are supported. No pages are inferred.")
                    }
                    if let feedback { AppToast(feedback) }
                    AppButton("Save Progress") {
                        if let result = model.perform({
                            let value: ReadingProgress
                            if reading.progress.mode == .page {
                                guard let current = Int(position) else { throw DomainError.invalidProgress }
                                value = try .pages(current: current, total: BooksModel.optionalPages(total))
                            } else {
                                guard let percent = Double(position) else { throw DomainError.invalidProgress }
                                value = try .percentage(percent)
                            }
                            return try model.repository.update(readingID: reading.id, value: value, revision: reading.revision, observationID: UUID())
                        }) {
                            switch result {
                            case .applied(let observation):
                                if let delta = observation.genuinePageDelta { feedback = (delta >= 0 ? "+" : "") + "\(delta) pages"; model.feedback = feedback }
                                saved(observation.value.suggestsFinishConfirmation)
                            case .requiresReview: model.error = "This observation was retained for review. It did not overwrite current progress."; saved(false)
                            }
                        }
                    }.accessibilityIdentifier("books.saveProgress")
                    BooksErrorMessage()
                }
            }
        }.onAppear {
            position = reading.progress.currentPage.map(String.init) ?? reading.progress.percentage.map { String($0) } ?? ""
            total = reading.progress.totalPages.map(String.init) ?? ""
        }
    }
}

struct ReadingHistoryScreen: View {
    @EnvironmentObject var model: BooksModel
    let bookID: UUID
    @State private var selected: ReadingInstance?
    var body: some View {
        BooksScreen("Reading History") {
            if let record = try? model.repository.record(id: bookID) {
                ForEach(record.readings, id: \.id) { reading in
                    VStack(alignment: .leading, spacing: 8) {
                        StatusChip(reading.status == .read ? "Read" : reading.status == .dnf ? "DNF" : "Currently Reading", symbol: "book")
                        Text("Start: " + (reading.startDate?.isoString ?? "Unknown")); Text("Finish: " + (reading.finishDate?.isoString ?? "Unknown"))
                        ReadingProgressBar(displayProgress(reading.progress)); Text(ratingLabel(reading.rating))
                        Text("Primary Genre: " + (reading.primaryGenre ?? "Unknown"))
                        AppButton("Edit this reading", kind: .secondary) { selected = reading }
                        ForEach(reading.progressObservations, id: \.id) { observation in
                            Text(displayProgress(observation.value).label + (observation.requiresReview ? " · Requires review" : ""))
                        }
                    }.padding(.vertical, 12)
                }
                if record.readings.isEmpty { Text("No reading history yet") }
            }
            BooksErrorMessage()
        }.sheet(item: $selected) { reading in NavigationStack { EditReadingScreen(reading: reading) } }
    }
}
extension ReadingInstance: Identifiable {}

struct EditReadingScreen: View {
    @EnvironmentObject var model: BooksModel
    @Environment(\.dismiss) var dismiss
    let reading: ReadingInstance
    @State private var start = ""
    @State private var finish = ""
    @State private var genre = ""
    @State private var format = "Unknown"
    @State private var rating = "Unknown"
    var body: some View {
        BooksScreen("Edit Reading") {
            BooksField(label: "Start date (YYYY-MM-DD or unknown)", value: $start)
            if reading.status == .read { BooksField(label: "Finish date (YYYY-MM-DD or unknown)", value: $finish) }
            BooksField(label: "Primary Genre", value: $genre)
            Text("One user-selected Primary Genre belongs to this reading. Provider categories are separate suggestions.")
            Picker("Rating", selection: $rating) { ForEach(["Unknown","No rating","1","2","3","4","5"], id: \.self) { Text($0).tag($0) } }.frame(minHeight: 44)
            Picker("Format — your choice only", selection: $format) { Text("Unknown").tag("Unknown"); ForEach(JournalFormat.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0.rawValue) } }.frame(minHeight: 44)
            AppButton("Save Reading Info") {
                if model.perform({
                    let selected: Rating = rating == "Unknown" ? .unknown : rating == "No rating" ? .noRating : try .validatedStars(Int(rating)!)
                    try model.repository.editReading(readingID: reading.id, start: BooksModel.parseDate(start), finish: BooksModel.parseDate(finish), rating: selected, genre: genre, format: JournalFormat(rawValue: format), revision: reading.revision)
                }) != nil { dismiss() }
            }
            BooksErrorMessage()
        }.onAppear {
            start = reading.startDate?.isoString ?? ""; finish = reading.finishDate?.isoString ?? ""; genre = reading.primaryGenre ?? ""
            format = reading.journalFormat?.rawValue ?? "Unknown"
            switch reading.rating { case .unknown: rating = "Unknown"; case .noRating: rating = "No rating"; case .stars(let stars): rating = String(stars) }
        }
    }
}

struct EditBookInfoScreen: View {
    @EnvironmentObject var model: BooksModel
    @Environment(\.dismiss) var dismiss
    let record: CatalogRecord
    @State private var title = ""
    @State private var author = ""
    @State private var cover = ""
    @State private var synopsis = ""
    @State private var series = ""
    @State private var genre = ""
    @State private var editionID: UUID?
    @State private var editionTitle = ""
    @State private var language = ""
    @State private var pages = ""
    @State private var isbn10 = ""
    @State private var isbn13 = ""
    @State private var publisher = ""
    var body: some View {
        BooksScreen("Edit Book Info") {
            BooksField(label: "Title", value: $title); BooksField(label: "Author", value: $author)
            CoverEditor(reference: $cover)
            BooksField(label: "External Book Synopsis", value: $synopsis)
            BooksField(label: "Series name", value: $series)
            BooksField(label: "Genre suggestion (not Primary Genre)", value: $genre)
            Text("Primary Genre, Format, dates and personal rating are edited per reading in Reading History.")
            if !record.editions.isEmpty {
                DisclosureGroup("Edition information") {
                    Picker("Edition", selection: $editionID) { ForEach(record.editions, id: \.id) { Text($0.title ?? "Edition").tag(Optional($0.id)) } }.frame(minHeight: 44)
                    BooksField(label: "Edition title", value: $editionTitle); BooksField(label: "Language", value: $language)
                    BooksField(label: "Edition pages", value: $pages); BooksField(label: "ISBN-10", value: $isbn10); BooksField(label: "ISBN-13", value: $isbn13); BooksField(label: "Publisher", value: $publisher)
                    Text("Editing edition pages does not rewrite previous reading observations or their denominators.")
                }.frame(minHeight: 44)
            }
            AppButton("Save Book Info") {
                if model.perform({
                    _ = try BooksRules.validatedText(title); _ = try BooksRules.validatedText(author)
                    let total = try BooksModel.optionalPages(pages)
                    if !cover.isEmpty, model.coverURL(cover) == nil { throw BooksError.invalidMetadata }
                    try model.repository.edit(bookID: record.id, values: [.title:title,.author:author,.cover:cover,.synopsis:synopsis,.series:series,.genreSuggestion:genre], revision: record.revision)
                    if var edition = record.editions.first(where: { $0.id == editionID }) {
                        edition.title = editionTitle.isEmpty ? nil : editionTitle; edition.language = language.isEmpty ? nil : language
                        edition.pageCount = total; edition.isbn10 = isbn10.isEmpty ? nil : isbn10; edition.isbn13 = isbn13.isEmpty ? nil : isbn13; edition.publisher = publisher.isEmpty ? nil : publisher
                        try model.repository.editEdition(edition, revision: record.revision + 1)
                    }
                }) != nil { dismiss() }
            }
            BooksErrorMessage()
        }.onAppear {
            title = record.book.title; author = record.book.author; cover = record.coverReference ?? ""; synopsis = record.synopsis ?? ""; series = record.seriesName ?? ""; genre = record.genreSuggestion ?? ""
            editionID = record.editions.first?.id; loadEdition()
        }.onChange(of: editionID) { loadEdition() }
    }
    private func loadEdition() {
        guard let e = record.editions.first(where: { $0.id == editionID }) else { return }
        editionTitle = e.title ?? ""; language = e.language ?? ""; pages = e.pageCount.map(String.init) ?? ""; isbn10 = e.isbn10 ?? ""; isbn13 = e.isbn13 ?? ""; publisher = e.publisher ?? ""
    }
}
