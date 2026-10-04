import SwiftUI
import ReadingDomain

public struct JournalHome: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.colorScheme) private var scheme
    @State private var inbox: [JournalInboxItem] = []
    @State private var usage: JournalUsage?
    @State private var session = false
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let usage {
                Text("My Journal · Volume \(usage.volume.number)").font(DesignTokens.journalAccent(size: 22))
                ReadingProgressBar(.pages(current: usage.bookReviews, total: JournalRules.bookReviewCapacity))
                Text("\(usage.bookReviewsRemaining) book reviews remaining · \(usage.favorites) favorites · \(usage.quotes) quotes")
                    .font(DesignTokens.functionalFont(size: 13)).foregroundStyle(DesignTokens.secondaryText(scheme))
            }
            if inbox.isEmpty {
                StatePresentation(kind: .empty, title: "Journal Inbox is clear", message: "Finish a book to prepare its journal components.")
            } else {
                ForEach(inbox) { item in
                    NavigationLink { BookReviewEditor(item: item, reload: reload) } label: {
                        HStack { BookRow(book: PreviewBook(id: item.book.id.uuidString, title: item.book.title, author: item.book.author, coverSymbol: "book.closed", detail: "Journal Inbox")); StatusChip(label(item.entry.bookReviewState), symbol: item.entry.bookReviewState == .ready ? "checkmark" : "ellipsis", tone: item.entry.bookReviewState == .ready ? .special : .neutral) }
                    }.buttonStyle(.plain)
                }
            }
            AppButton("Start Journal Session", symbol: "book.pages", action: { session = true })
                .disabled((try? model.journalRepository?.readyForSession().isEmpty) ?? true)
                .accessibilityIdentifier("journal.startSession")
            NavigationLink("Review journal corrections") { JournalCorrections() }
                .frame(minHeight: 44).accessibilityIdentifier("journal.corrections")
        }.onAppear(perform: reload)
            .journalSessionPresentation(isPresented: $session) { JournalSession() }
    }
    private func label(_ state: JournalComponentStatus) -> String { state == .ready ? "Ready" : state == .copied ? "Copied" : "Pending" }
    private func reload() { guard let repo = model.journalRepository else { return }; inbox = (try? repo.journalInbox()) ?? []; usage = try? repo.journalUsage() }
}

private extension View {
    @ViewBuilder func journalSessionPresentation<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
}

private struct BookReviewEditor: View {
    @EnvironmentObject var model: BooksModel
    let item: JournalInboxItem; let reload: () -> Void
    @State private var summary = ""; @State private var pages = ""
    @State private var rating = 0; @State private var format = ""
    @State private var favorite = JournalDecision.pending
    @State private var quote = ""; @State private var source = ""; @State private var physical = true
    var body: some View {
        BooksScreen("Book Review") {
            Text(item.book.title).font(DesignTokens.journalAccent(size: 24)); Text(item.book.author)
            BooksField(label: "Summary", value: $summary)
            Text("Summary assistant unavailable — write or edit your own summary.").font(.footnote)
            BooksField(label: "Pages", value: $pages)
            Picker("Rating", selection: $rating) { Text("Choose rating").tag(0); ForEach(1...5, id: \.self) { Text("\($0) stars").tag($0) } }
            Picker("Journal format", selection: $format) { Text("Choose format").tag(""); Text("Paperback").tag("paperback"); Text("Hardcover").tag("hardcover"); Text("Ebook").tag("ebook"); Text("Audiobook").tag("audiobook") }
            AppButton("Save Book Review") { saveReview() }.accessibilityIdentifier("journal.saveReview")
            Text("Favorite").font(.headline)
            AppSegmentedControl(options: [(JournalDecision.selected,"Favorite"),(JournalDecision.none,"Not favorite")], selection: $favorite)
            Text("Quote").font(.headline); BooksField(label: "Quote text", value: $quote); BooksField(label: "Source or page", value: $source)
            Toggle("Include in physical journal", isOn: $physical)
            HStack { AppButton("Save Quote", kind: .secondary) { saveQuote() }; AppButton("No quote", kind: .tertiary) { setNoQuote() } }
            BooksErrorMessage()
        }.onAppear { summary = item.entry.summary ?? ""; pages = item.entry.pageCount.map(String.init) ?? ""; if case .stars(let stars) = item.reading.rating { rating = stars }; format = item.reading.journalFormat?.rawValue ?? ""; favorite = (try? model.journalRepository?.favoriteDecision(bookID: item.book.id)) ?? .pending }
    }
    private func saveReview() { guard let repo = model.journalRepository, let chosen = JournalFormat(rawValue: format), rating > 0 else { model.error = "Choose a rating and journal format."; return }; _ = model.perform { try repo.saveBookReview(readingID: item.reading.id, draft: BookReviewDraft(summary: summary, pageCount: try BooksModel.optionalPages(pages), rating: .stars(rating), format: chosen, start: item.reading.startDate, finish: item.reading.finishDate)); try repo.setFavorite(bookID: item.book.id, decision: favorite) }; reload() }
    private func saveQuote() { guard let repo = model.journalRepository else { return }; _ = model.perform { try repo.saveQuote(JournalQuote(bookID: item.book.id, readingID: item.reading.id, text: quote, source: source, includeInJournal: physical)) } }
    private func setNoQuote() { guard let repo = model.journalRepository else { return }; _ = model.perform { try repo.setNoQuote(readingID: item.reading.id, value: true) } }
}

private struct JournalSession: View {
    @EnvironmentObject var model: BooksModel; @Environment(\.dismiss) var dismiss
    @State private var items: [JournalInboxItem] = []; @State private var index = 0
    var body: some View { NavigationStack { BooksScreen("Journal Session") {
        if items.isEmpty { StatePresentation(kind: .empty, title: "Nothing ready", message: "Complete a Book Review first.") }
        else { let item = items[index]; Text("\(index + 1) of \(items.count)"); ReadingProgressBar(.pages(current: index + 1, total: items.count)); Text(item.book.title).font(DesignTokens.journalAccent(size: 26)); Text(item.entry.summary ?? ""); AppButton("Copied") { mark(item) }.accessibilityIdentifier("journal.copied") }
    }.toolbar { Button("Close") { dismiss() } } }.onAppear { items = (try? model.journalRepository?.readyForSession()) ?? [] } }
    private func mark(_ item: JournalInboxItem) { guard let repo = model.journalRepository else { return }; if model.perform({ try repo.markBookReviewCopied(readingID: item.reading.id) }) != nil { if index + 1 < items.count { index += 1 } else { dismiss() } } }
}

private struct JournalCorrections: View {
    @EnvironmentObject var model: BooksModel; @State private var rows: [JournalCorrection] = []
    var body: some View { BooksScreen("Journal Corrections") { if rows.isEmpty { StatePresentation(kind: .empty, title: "No corrections", message: "Changes made after copying will appear here.") }; ForEach(rows) { row in VStack(alignment: .leading, spacing: 8) { HStack { Text(row.field).font(.headline); Spacer(); StatusChip(row.resolved ? "Resolved" : "Pending", symbol: row.resolved ? "checkmark" : "pencil", tone: row.resolved ? .special : .neutral) }; Text("Copied: \(row.previousValue)"); Text("Current: \(row.currentValue)"); if !row.resolved { AppButton("Mark corrected", kind: .secondary) { resolve(row) } } } } }.onAppear(perform: load) }
    private func load() { rows = (try? model.journalRepository?.corrections()) ?? [] }
    private func resolve(_ row: JournalCorrection) { _ = model.perform { try model.journalRepository?.resolveCorrection(id: row.id) }; load() }
}
