import SwiftUI
import UniformTypeIdentifiers
import ReadingDomain

public struct ImportHome: View {
    @EnvironmentObject private var model: BooksModel
    @State private var selecting = false
    @State private var preview: ImportPreview?
    @State private var history = [ImportHistory]()
    @State private var candidates = [ImportCandidate]()
    @State private var reviews = [ImportReview]()
    @State private var message: String?
    @State private var busy = false
    @State private var confirm = false
    @State private var lastImport: ImportHistory?
    private var repository: (any ImportsRepository)? { model.repository as? any ImportsRepository }
    public init() {}
    public var body: some View {
        BooksScreen("StoryGraph Import") {
            Text("Bring your reading history with you").font(DesignTokens.functionalFont(size:22,relativeTo:.title2,weight:.semiBold)).fixedSize(horizontal:false,vertical:true)
            Text("Choose your StoryGraph CSV, review the preview, then confirm. Your current data stays authoritative; changes require your decision.").fixedSize(horizontal:false,vertical:true)
            Text("Historical readings receive no XP, Quest progress, Achievements, automatic Challenges or Journal Inbox work. Format is always your own choice.").font(DesignTokens.functionalFont(size:14)).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("import.safety")
            AppButton("Choose CSV file",symbol:"doc",action:{ selecting=true }).disabled(busy).accessibilityIdentifier("import.choose")
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-phase8-fixture") {
                AppButton("Load fictional StoryGraph CSV",kind:.secondary,action:{ load(StoryGraphImportFixture.initial) }).accessibilityIdentifier("import.fixture.initial")
                AppButton("Load fictional reconciliation CSV",kind:.secondary,action:{ load(StoryGraphImportFixture.reconcile) }).accessibilityIdentifier("import.fixture.reconcile")
            }
            #endif
            if busy { ProgressView("Preparing preview") }
            if let message { StatePresentation(kind:.error,title:"Import not applied",message:message).accessibilityIdentifier("import.error") }
            if let preview {
                Text("Preview").font(DesignTokens.functionalFont(size:22,relativeTo:.title2,weight:.semiBold)).accessibilityIdentifier("import.preview")
                Text("\(preview.candidates.count) source rows • No changes yet").fixedSize(horizontal:false,vertical:true)
                ForEach(ImportGroup.allCases,id:\.self) { group in
                    VStack(alignment:.leading,spacing:12) {
                        Text("\(group.rawValue) · \(preview.count(group))").font(DesignTokens.functionalFont(size:18,relativeTo:.headline,weight:.semiBold)).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("import.group."+group.rawValue)
                        ForEach(preview.candidates.filter { $0.group == group }) { candidate in
                            ImportCandidateSummary(candidate:candidate)
                        }
                    }
                }
                Text("Confirm imports supported new history and queues differences for review. Needs Review rows stay unapplied. Already Up to Date rows are left unchanged.").fixedSize(horizontal:false,vertical:true)
                AppButton("Confirm import",action:{confirm=true}).disabled(busy).accessibilityIdentifier("import.confirm")
                AppButton("Cancel preview",kind:.secondary,action:{self.preview=nil}).accessibilityIdentifier("import.cancel")
            }
            if let lastImport {
                StatusChip("Import saved",symbol:"checkmark")
                Text("\(lastImport.newBooks) new books · \(lastImport.newReadings) historical readings. \(lastImport.review) source rows queued for review.").fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("import.result")
                NavigationLink("View imported books") { MyBooksScreen() }.buttonStyle(ProfileLinkStyle()).accessibilityIdentifier("import.library")
            }
            NavigationLink("Needs Review · \(candidates.count + reviews.count)") { ImportNeedsReview() }.buttonStyle(ProfileLinkStyle()).accessibilityIdentifier("import.needsReview")
            NavigationLink("Import History · \(history.count)") { ImportHistoryScreen() }.buttonStyle(ProfileLinkStyle()).accessibilityIdentifier("import.history")
        }.task(id:model.version) { reload() }
        .confirmationDialog("Import this preview?",isPresented:$confirm,titleVisibility:.visible) {
            Button("Import supported history") { apply() }
            Button("Cancel",role:.cancel) {}
        } message: { Text("Existing values are preserved. Differences and uncertain rows require review. No historical rewards or completion cascades will run.") }
        .fileImporter(isPresented:$selecting,allowedContentTypes:[.commaSeparatedText],allowsMultipleSelection:false) { result in
            do {
                guard let url=try result.get().first else { return }
                let granted=url.startAccessingSecurityScopedResource();defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let handle=try FileHandle(forReadingFrom:url);defer { try? handle.close() }
                let data=try handle.read(upToCount:10_000_001) ?? Data()
                guard data.count<=10_000_000 else { throw ImportError.oversized }
                load(data)
            } catch { message=error.localizedDescription }
        }
    }
    private func load(_ data:Data) {
        guard let repository else { return }; busy=true; message=nil;preview=nil
        Task {
            do { preview=try await Task.detached { try repository.previewStoryGraph(data) }.value }
            catch { message=error.localizedDescription }
            busy=false
        }
    }
    private func apply() {
        guard let preview,let repository else { return }
        do { lastImport=try repository.applyImport(preview,confirmed:true);self.preview=nil;model.version+=1;message=nil;reload() }
        catch { message=error.localizedDescription }
    }
    private func reload() {
        do { history=try repository?.importHistory() ?? [];candidates=try repository?.pendingImportCandidates() ?? [];reviews=try repository?.importReviews() ?? [] }
        catch { message="Could not load import history. Existing data is unchanged." }
    }
}

private struct ImportCandidateSummary: View {
    let candidate:ImportCandidate
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            BookRow(book:PreviewBook(id:candidate.id.uuidString,title:candidate.row.title.isEmpty ? "Title unknown":candidate.row.title,author:candidate.row.author.isEmpty ? "Author unknown":candidate.row.author,detail:"Source row \(candidate.row.number) · \(candidate.row.status.isEmpty ? "Status unknown":candidate.row.status)"))
            Text(candidate.explanation).font(DesignTokens.functionalFont(size:14)).fixedSize(horizontal:false,vertical:true)
            if candidate.row.status == "read" {
                Text("\(candidate.row.finishes.count) completed occurrence(s) · Finish: \(candidate.row.finishes.last.flatMap { $0 }?.isoString ?? "Unknown") · Pages: Unknown · Format: User only").font(DesignTokens.functionalFont(size:14)).fixedSize(horizontal:false,vertical:true)
            }
            Divider()
        }
    }
}

struct ImportNeedsReview:View {
    @EnvironmentObject private var model:BooksModel
    @State private var candidates=[ImportCandidate]()
    @State private var reviews=[ImportReview]()
    @State private var error:String?
    var body:some View { BooksScreen("Import Needs Review") {
        Text("Your current data is preserved until you decide.").fixedSize(horizontal:false,vertical:true)
        if candidates.isEmpty && reviews.isEmpty { Text("Nothing needs review.").accessibilityIdentifier("import.review.empty") }
        ForEach(reviews) { review in
            VStack(alignment:.leading,spacing:12) {
                if review.userOverridden { StatusChip("Your correction is protected",symbol:"hand.raised").accessibilityIdentifier("import.protected") }
                DataChangeReview(field:fieldLabel(review.field),current:review.current,proposed:review.proposed,source:"StoryGraph CSV",accept:{ decide(review,true) },keep:{ decide(review,false) },edit:{ editID=review.entityID })
                Text("Accept is your explicit correction; Keep suppresses the same source evidence.").font(DesignTokens.functionalFont(size:14)).fixedSize(horizontal:false,vertical:true)
            }.accessibilityIdentifier("import.review."+review.field)
        }
        ForEach(candidates) { candidate in
            NavigationLink { ImportIdentityReview(candidate:candidate) } label: { ImportCandidateSummary(candidate:candidate).padding(.vertical,8).frame(minHeight:44).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityIdentifier("import.candidate."+String(candidate.row.number))
        }
        if let error { StatePresentation(kind:.error,title:"Decision not applied",message:error) }
    }.task(id:model.version) { reload() }.sheet(isPresented:Binding(get:{editID != nil},set:{ if !$0 { editID=nil } })) {
        if let id=editID { NavigationStack { ImportManualEdit(entityID:id) } }
    } }
    @State private var editID:UUID?
    private func fieldLabel(_ field:String) -> String { switch field { case "start_date":"Start date";case "finish_date":"Finish date";case "rating":"Rating";case "title":"Title";case "author":"Author";default:field } }
    private func decide(_ review:ImportReview,_ accept:Bool) { do { try (model.repository as? any ImportsRepository)?.decideImport(id:review.id,accept:accept);model.version+=1;reload() } catch { self.error=error.localizedDescription } }
    private func reload() { do { let repo=model.repository as? any ImportsRepository;candidates=try repo?.pendingImportCandidates() ?? [];reviews=try repo?.importReviews() ?? [] } catch { self.error="Could not load pending review." } }
}

private struct ImportManualEdit:View {
    @EnvironmentObject private var model:BooksModel
    let entityID:UUID
    @State private var bookID:UUID?
    var body:some View { Group { if let bookID { BookPageScreen(bookID:bookID) } else { Text("Open the book in My Books to correct its reading information.").padding() } }.task {
        if (try? model.repository.record(id:entityID)) != nil { bookID=entityID }
        else { bookID=(try? model.repository.library(query:"",view:.all,sort:.title,filters:.init(),limit:10000,offset:0))?.first { $0.readings.contains { $0.id == entityID } }?.id }
    } }
}

private struct ImportIdentityReview:View {
    @EnvironmentObject private var model:BooksModel
    @Environment(\.dismiss) private var dismiss
    let candidate:ImportCandidate
    @State private var selected:UUID?
    @State private var separate=false
    @State private var readingMap=[Int:UUID]()
    @State private var linking=false
    @State private var confirm=false
    @State private var skip=false
    @State private var error:String?
    var body:some View { BooksScreen("Review Imported Book") {
        ImportCandidateSummary(candidate:candidate)
        if candidate.row.issues.isEmpty {
            Text("Select the canonical book explicitly. Existing readings stay intact; this adds distinct historical occurrences, never a live completion.").fixedSize(horizontal:false,vertical:true)
            ForEach(candidate.matches,id:\.self) { id in
                if let record=try? model.repository.record(id:id) {
                    AppButton("Use existing: "+record.book.title,kind:.secondary,action:{selected=id;separate=false;readingMap=[:];linking=false}).accessibilityIdentifier("import.identity.existing")
                    if selected == id { StatusChip("Selected existing book",symbol:"checkmark") }
                    if selected == id,candidate.row.status == "read",!record.readings.filter({$0.status == .read}).isEmpty {
                        AppButton("Match existing readings",kind:.secondary,action:{linking=true;readingMap=[:]}).accessibilityIdentifier("import.identity.link")
                        AppButton("Add distinct historical readings",kind:.secondary,action:{linking=false;readingMap=[:]}).accessibilityIdentifier("import.identity.newReadings")
                        if linking {
                            ForEach(Array(candidate.row.finishes.indices),id:\.self) { index in
                                Text("Imported occurrence \(index+1) · \(candidate.row.finishes[index]?.isoString ?? "Date unknown")").fixedSize(horizontal:false,vertical:true)
                                ForEach(record.readings.filter{$0.status == .read},id:\.id) { reading in
                                    AppButton("Use reading · \(reading.finishDate?.isoString ?? "Date unknown")",kind:.secondary,action:{readingMap[index]=reading.id}).accessibilityIdentifier("import.identity.reading."+String(index))
                                    if readingMap[index] == reading.id { StatusChip("Selected reading",symbol:"checkmark") }
                                }
                            }
                        } else { Text("Distinct history selected. Use Match existing readings if these occurrences already exist locally.").fixedSize(horizontal:false,vertical:true) }
                    }
                }
            }
            AppButton("Create a separate book",kind:.secondary,action:{selected=nil;separate=true;linking=false;readingMap=[:]}).accessibilityIdentifier("import.identity.separate")
            if separate { StatusChip("Selected separate book",symbol:"checkmark") }
            AppButton("Confirm identity and history",action:{confirm=true}).disabled((selected == nil && !separate) || (linking && (readingMap.count != candidate.row.finishes.count || Set(readingMap.values).count != readingMap.count))).accessibilityIdentifier("import.identity.confirm")
        } else { Text("Correct the CSV and import it again, or keep this row unapplied. Missing dates remain unknown; unsupported content is never inferred.").fixedSize(horizontal:false,vertical:true) }
        AppButton("Keep row unapplied",kind:.secondary,action:{skip=true}).accessibilityIdentifier("import.identity.skip")
        if let error { StatePresentation(kind:.error,title:"Review not applied",message:error) }
    }.confirmationDialog("Confirm imported identity and distinct history?",isPresented:$confirm,titleVisibility:.visible) {
        Button("Apply selected identity") { do {
            let repo=model.repository as? any ImportsRepository
            if linking,let selected { try repo?.linkImportCandidate(id:candidate.id,bookID:selected,readingIDs:candidate.row.finishes.indices.compactMap { readingMap[$0] },confirmed:true) }
            else { try repo?.resolveImportCandidate(id:candidate.id,bookID:selected,createSeparateBook:separate,confirmed:true) }
            model.version+=1;dismiss()
        } catch { self.error=error.localizedDescription } }
    }.confirmationDialog("Keep this row unapplied?",isPresented:$skip,titleVisibility:.visible) {
        Button("Keep unapplied") { do { try (model.repository as? any ImportsRepository)?.skipImportCandidate(id:candidate.id,confirmed:true);model.version+=1;dismiss() } catch { self.error=error.localizedDescription } }
    } }
}

struct ImportHistoryScreen:View {
    @EnvironmentObject private var model:BooksModel
    @State private var history=[ImportHistory]()
    @State private var error:String?
    var body:some View { BooksScreen("Import History") {
        Text("Committed imports only. Counts record what was saved at confirmation; later review decisions preserve this history.").fixedSize(horizontal:false,vertical:true)
        if history.isEmpty { Text("No confirmed imports yet.") }
        ForEach(history) { run in
            VStack(alignment:.leading,spacing:8) {
                Text("StoryGraph CSV").font(DesignTokens.functionalFont(size:18,relativeTo:.headline,weight:.semiBold))
                Text(run.completedAt).font(DesignTokens.functionalFont(size:14)).fixedSize(horizontal:false,vertical:true)
                Text("\(run.rows) source rows · \(run.newBooks) new books · \(run.newReadings) historical readings").fixedSize(horizontal:false,vertical:true)
                Text("\(run.review) queued for review · \(run.unchanged) already up to date").fixedSize(horizontal:false,vertical:true)
                StatusChip("Committed · No live rewards",symbol:"checkmark")
                Divider()
            }.accessibilityIdentifier("import.history.row")
        }
        if let error { Text(error) }
    }.task { do { history=try (model.repository as? any ImportsRepository)?.importHistory() ?? [] } catch { self.error="Could not load committed history." } } }
}

#if DEBUG
public enum StoryGraphImportFixture {
    // Explicit fictional fixture, parsed by the production adapter; no assigned preview, readings or reward state.
    public static let initial=Data("Title,Authors,ISBN/UID,Read Status,Read Count,Dates Read,Last Date Read,Star Rating,Format\nThe Lantern Archive,Avery Reader,fixture-lantern,read,2,\"2024/01/02-2024/01/09,2025/02/01-2025/02/08\",,4,ebook\nThe Unknown Shore,Robin Author,fixture-unknown,read,1,,,0,audiobook\nA Future Reading,Morgan Author,fixture-future,to-read,0,,,,hardcover\n".utf8)
    public static let reconcile=Data("Title,Authors,ISBN/UID,Read Status,Read Count,Dates Read,Last Date Read,Star Rating,Format\nThe Lantern Archive Revised,Avery Reader,fixture-lantern,read,2,\"2024/01/02-2024/01/09,2025/02/01-2025/02/10\",,5,paperback\nThe Unknown Shore,Robin Author,fixture-unknown,read,1,,,0,ebook\nThe Lantern Archive,Avery Reader,fixture-ambiguous,read,1,,,4,ebook\nAn Uncertain Date,Taylor Author,fixture-date,read,1,,03/04/2025,3.5,hardcover\n".utf8)
}
#endif
