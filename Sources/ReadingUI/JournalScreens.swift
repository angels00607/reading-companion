import SwiftUI
import ReadingDomain

public struct JournalHome: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var inbox: [JournalInboxItem] = []
    @State private var usage: JournalUsage?
    @State private var session = false
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let usage {
                VStack(alignment: .leading, spacing: 12) {
                    Text("My Journal · Volume \(usage.volume.number)").font(typeSize.isAccessibilitySize ? DesignTokens.functionalFont(size: 20, relativeTo: .title3, weight: .semiBold) : DesignTokens.journalAccent(size: 20)).fixedSize(horizontal: false, vertical: true)
                    Text("\(usage.bookReviews) of \(JournalRules.bookReviewCapacity) book reviews")
                        .font(DesignTokens.functionalFont(size: 17, relativeTo: .headline, weight: .semiBold))
                    ReadingProgressBar(.pages(current: usage.bookReviews, total: JournalRules.bookReviewCapacity), showsLabel: false)
                    Text("\(usage.bookReviewsRemaining) review slots remaining")
                    Text("\(usage.favorites) favorites · \(usage.quotes) quotes selected for this volume")
                        .foregroundStyle(DesignTokens.secondaryText(scheme))
                }.font(DesignTokens.functionalFont(size: 13)).padding(16)
                    .background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
            }
            if inbox.isEmpty {
                StatePresentation(kind: .empty, title: "Journal Inbox is clear", message: "Finish a book to prepare its journal components.")
            } else {
                ForEach(inbox) { item in
                    NavigationLink { BookReviewEditor(item: item, reload: reload) } label: {
                        JournalInboxCard(item: item)
                    }.buttonStyle(.plain)
                }
            }
            AppButton("Start Journal Session", symbol: "book.pages", action: { session = true })
                .disabled((try? model.journalRepository?.readyForSession().isEmpty) ?? true)
                .accessibilityIdentifier("journal.startSession")
            NavigationLink("Review journal corrections") { JournalCorrections() }
                .frame(minHeight: 44).accessibilityIdentifier("journal.corrections")
        }.padding(.bottom, 64).onAppear(perform: reload)
            .journalSessionPresentation(isPresented: $session) { JournalSession() }
    }
    private func label(_ state: JournalComponentStatus) -> String { state == .ready ? "Ready" : state == .copied ? "Copied" : "Pending" }
    private func reload() { guard let repo = model.journalRepository else { return }; inbox = (try? repo.journalInbox()) ?? []; usage = try? repo.journalUsage() }
}

private struct JournalInboxCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    let item: JournalInboxItem
    private var status: String { item.entry.bookReviewState == .ready ? "Ready" : item.entry.bookReviewState == .copied ? "Copied" : "Pending" }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if typeSize.isAccessibilitySize {
                metadata
                StatusChip(status, symbol: item.entry.bookReviewState == .ready ? "checkmark" : "ellipsis", tone: item.entry.bookReviewState == .ready ? .special : .neutral)
            } else {
                HStack(alignment: .top, spacing: 12) { BookCover(title: item.book.title, symbol: "book.closed"); metadata; Spacer(minLength: 8); StatusChip(status, symbol: item.entry.bookReviewState == .ready ? "checkmark" : "ellipsis", tone: item.entry.bookReviewState == .ready ? .special : .neutral) }
            }
        }.padding(14).background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
            .accessibilityElement(children: .combine).accessibilityLabel("\(item.book.title), by \(item.book.author), Book Review \(status)")
    }
    private var metadata: some View { VStack(alignment: .leading, spacing: 4) {
        Text(item.book.title).font(DesignTokens.functionalFont(size: 17, relativeTo: .headline, weight: .semiBold)).fixedSize(horizontal: false, vertical: true)
        Text(item.book.author).font(DesignTokens.functionalFont(size: 14, relativeTo: .subheadline)).foregroundStyle(DesignTokens.secondaryText(scheme))
        Text("Book Review").font(DesignTokens.functionalFont(size: 12, relativeTo: .caption, weight: .medium)).foregroundStyle(DesignTokens.secondaryText(scheme))
    } }
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
            Text(item.book.title).font(DesignTokens.functionalFont(size: 24, relativeTo: .title2, weight: .semiBold)); Text(item.book.author).foregroundStyle(.secondary)
            JournalSection("Review details") { BooksField(label: "Summary", value: $summary); Text("Summary assistant is unavailable. You can write or edit your summary manually.").font(.footnote).foregroundStyle(.secondary); BooksField(label: "Pages", value: $pages) }
            JournalSection("Your reading") {
                Picker("Rating", selection: $rating) { Text("Choose rating").tag(0); Text("No rating").tag(-1); ForEach(1...5, id: \.self) { Text("\($0) stars").tag($0) } }.frame(minHeight: 44)
                Picker("Format", selection: $format) { Text("Choose format").tag(""); Text("Paperback").tag("paperback"); Text("Hardcover").tag("hardcover"); Text("Ebook").tag("ebook"); Text("Audiobook").tag("audiobook") }.frame(minHeight: 44)
            }
            AppButton("Save Book Review") { saveReview() }.accessibilityIdentifier("journal.saveReview")
            JournalSection("Favorite") { Text("Choose whether this book belongs in your physical Favorites section.").font(.footnote).foregroundStyle(.secondary); AppSegmentedControl(options: [(JournalDecision.selected,"Favorite"),(JournalDecision.none,"Not favorite")], selection: $favorite) }
            JournalSection("Quote") { BooksField(label: "Quote text", value: $quote); BooksField(label: "Source or page (optional)", value: $source); Toggle("Copy this quote to my physical journal", isOn: $physical).frame(minHeight: 44); ViewThatFits { HStack { quoteButtons }; VStack(spacing: 8) { quoteButtons } } }
            BooksErrorMessage()
        }.onAppear { summary = item.entry.summary ?? ""; pages = item.entry.pageCount.map(String.init) ?? ""; switch item.reading.rating { case .stars(let stars): rating = stars; case .noRating: rating = -1; case .unknown: rating = 0 }; format = item.reading.journalFormat?.rawValue ?? ""; favorite = (try? model.journalRepository?.favoriteDecision(bookID: item.book.id)) ?? .pending }
    }
    private func saveReview() { guard let repo = model.journalRepository, let chosen = JournalFormat(rawValue: format), rating != 0 else { model.error = "Choose a rating or No rating, and a journal format."; return }; let selectedRating: Rating = rating == -1 ? .noRating : .stars(rating); _ = model.perform { try repo.saveBookReview(readingID: item.reading.id, draft: BookReviewDraft(summary: summary, pageCount: try BooksModel.optionalPages(pages), rating: selectedRating, format: chosen, start: item.reading.startDate, finish: item.reading.finishDate)); try repo.setFavorite(bookID: item.book.id, decision: favorite) }; reload() }
    private func saveQuote() { guard let repo = model.journalRepository else { return }; _ = model.perform { try repo.saveQuote(JournalQuote(bookID: item.book.id, readingID: item.reading.id, text: quote, source: source, includeInJournal: physical)) } }
    private func setNoQuote() { guard let repo = model.journalRepository else { return }; _ = model.perform { try repo.setNoQuote(readingID: item.reading.id, value: true) } }
}

private struct JournalSection<Content: View>: View {
    @Environment(\.colorScheme) private var scheme; let title: String; @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View { VStack(alignment: .leading, spacing: 12) { Text(title.uppercased()).font(DesignTokens.functionalFont(size: 13, relativeTo: .caption, weight: .semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme)); content }.padding(.vertical, 4) }
}

private extension BookReviewEditor {
    @ViewBuilder var quoteButtons: some View { AppButton("Save Quote", kind: .secondary) { saveQuote() }; AppButton("No quote", kind: .tertiary) { setNoQuote() } }
}

private struct JournalSession: View {
    @EnvironmentObject var model: BooksModel; @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var items: [JournalInboxItem] = []; @State private var index = 0
    var body: some View { NavigationStack { BooksScreen("Journal Session") {
        if items.isEmpty { StatePresentation(kind: .empty, title: "Nothing ready", message: "Complete a Book Review first.") }
        else { let item = items[index]; Text("Copying \(index + 1) of \(items.count)").font(DesignTokens.functionalFont(size: 14, weight: .medium)); ReadingProgressBar(.pages(current: index + 1, total: items.count), showsLabel: false); VStack(alignment: .leading, spacing: 14) { Text("COPY TO YOUR JOURNAL").font(DesignTokens.functionalFont(size: 12, relativeTo: .caption, weight: .semiBold)).foregroundStyle(.secondary); Text(item.book.title).font(DesignTokens.functionalFont(size: 24, relativeTo: .title2, weight: .semiBold)); Text(item.book.author).foregroundStyle(.secondary); Divider(); if let pages = item.entry.pageCount { copyField("Pages", "\(pages)") }; copyField("Rating", rating(item.reading.rating)); if let format = item.reading.journalFormat { copyField("Format", format.rawValue.capitalized) }; if let start = item.reading.startDate { copyField("Start", start.isoString) }; if let finish = item.reading.finishDate { copyField("Finish", finish.isoString) }; copyField("Summary", item.entry.summary ?? "") }.padding(18).background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius)); AppButton("Copied to my journal") { mark(item) }.accessibilityIdentifier("journal.copied") }
    }.toolbar { Button("Close") { dismiss() } } }.onAppear { items = (try? model.journalRepository?.readyForSession()) ?? [] } }
    private func mark(_ item: JournalInboxItem) { guard let repo = model.journalRepository else { return }; if model.perform({ try repo.markBookReviewCopied(readingID: item.reading.id) }) != nil { if index + 1 < items.count { index += 1 } else { dismiss() } } }
    private func rating(_ value: Rating) -> String { switch value { case .unknown: "Unknown"; case .noRating: "No rating"; case .stars(let count): "\(count) stars" } }
    @ViewBuilder private func copyField(_ label: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 3) { Text(label.uppercased()).font(DesignTokens.functionalFont(size: 11, relativeTo: .caption, weight: .semiBold)).foregroundStyle(.secondary); Text(value).fixedSize(horizontal: false, vertical: true) } }
}

struct JournalCorrections: View {
    @EnvironmentObject var model: BooksModel; @State private var rows: [JournalCorrection] = []
    @Environment(\.colorScheme) private var scheme
    var body: some View { BooksScreen("Journal Corrections") { if rows.isEmpty { StatePresentation(kind: .empty, title: "No corrections", message: "Changes made after copying will appear here.") }; ForEach(rows) { row in VStack(alignment: .leading, spacing: 14) { HStack { Text(row.field).font(DesignTokens.functionalFont(size: 18, relativeTo: .headline, weight: .semiBold)); Spacer(); StatusChip(row.resolved ? "Resolved" : "Pending", symbol: row.resolved ? "checkmark" : "pencil", tone: row.resolved ? .special : .neutral) }; correctionValue("Copied in journal", row.previousValue); correctionValue("Current value", row.currentValue); if !row.resolved { AppButton("I've corrected my journal", kind: .secondary) { resolve(row) } } }.padding(16).background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius)) } }.onAppear(perform: load) }
    private func load() { rows = (try? model.journalRepository?.corrections()) ?? [] }
    private func resolve(_ row: JournalCorrection) { _ = model.perform { try model.journalRepository?.resolveCorrection(id: row.id) }; load() }
    @ViewBuilder private func correctionValue(_ label: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 5) { Text(label.uppercased()).font(DesignTokens.functionalFont(size: 12, relativeTo: .caption, weight: .semiBold)).foregroundStyle(.secondary); Text(value).fixedSize(horizontal: false, vertical: true) } }
}
