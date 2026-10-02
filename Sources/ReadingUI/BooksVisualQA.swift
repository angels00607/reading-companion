import SwiftUI
import ReadingDomain

/// Explicit test routes. Called only from opt-in DEBUG app launches.
public struct BooksVisualQA: View {
    @EnvironmentObject private var model: BooksModel
    public let route: String
    @State private var id: UUID?
    @State private var work: WorkCandidate?
    public init(route: String) { self.route = route }
    public var body: some View {
        NavigationStack {
            Group {
                if let id, let record = try? model.repository.record(id: id), let work {
                    switch route {
                    case "Global Search", "Search Results": GlobalSearchScreen()
                    case "Edition Selection": EditionSelectionScreen(work: work)
                    case "Manual Add": ManualAddScreen()
                    case "My Books": MyBooksScreen()
                    case "Update Progress Page", "Update Progress Percentage":
                        if let active = record.active { UpdateProgressScreen(reading: active, saved: { _ in }) }
                    case "Reading History": ReadingHistoryScreen(bookID: id)
                    case "Edit Book Info": EditBookInfoScreen(record: record)
                    case "Finish confirmation": BookPageScreen(bookID: id, showFinishOnAppear: true)
                    default: BookPageScreen(bookID: id)
                    }
                } else { SkeletonRow() }
            }.task {
                guard id == nil else { return }
                _ = model.perform {
                    let candidate = WorkCandidate(provider: "qa-fixture", reference: "visual-work", title: "The Long Way Home — A Deliberately Long Phase 2 QA Fixture Title", author: "An Extended Author Display Name for Compact Screen Review", synopsis: "Clearly labelled QA metadata. Not an actual published book.")
                    work = candidate
                    let eid = EditionCandidate(provider: "qa-fixture", reference: "visual-edition", title: candidate.title, language: "en", pageCount: 400, publisher: "QA only")
                    let bid = try model.repository.add(work: candidate, edition: eid, choice: .addAnyway)
                    if !["To Read","Global Search","Search Results","Edition Selection","Manual Add","My Books"].contains(route) {
                        let selected = try model.repository.record(id: bid).editions.first?.id
                        let rid = try model.repository.start(bookID: bid, editionID: selected, mode: route == "Update Progress Percentage" ? .percentage : .page, date: BooksModel.today)
                        _ = try model.repository.update(readingID: rid, value: route == "Update Progress Percentage" ? .percentage(57.5) : .pages(current: 257, total: 400), revision: 0, observationID: UUID())
                        if route == "DNF" { try model.repository.markDNF(readingID: rid, revision: 1) }
                        if route == "Reading History" {
                            try model.repository.finish(readingID: rid, confirmed: true, date: BooksModel.today, revision: 1)
                            _ = try model.repository.start(bookID: bid, editionID: selected, mode: .page, date: BooksModel.today)
                        }
                    }
                    id = bid
                }
            }
        }
    }
}
