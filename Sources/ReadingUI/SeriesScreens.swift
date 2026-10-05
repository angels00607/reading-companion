import SwiftUI
import ReadingDomain

public struct SeriesHome: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.colorScheme) private var scheme
    @State private var query = ""
    @State private var filter: SeriesFilter = .all
    @State private var sort: SeriesSort = .recentlyUpdated
    @State private var rows: [SeriesDetail] = []
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Search series or book", text: $query).textFieldStyle(.roundedBorder).frame(minHeight: 44)
                .accessibilityIdentifier("series.search").onChange(of: query) { _,_ in reload() }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(SeriesFilter.allCases, id: \.self) { option in FilterChip(option.rawValue, isSelected: Binding(get: { filter == option }, set: { if $0 { filter = option; reload() } })) } }
            }
            Menu { ForEach(SeriesSort.allCases, id: \.self) { option in Button(option.rawValue) { sort = option; reload() } } } label: {
                Label("Sort: \(sort.rawValue)", systemImage: "arrow.up.arrow.down").frame(minHeight: 44)
            }.accessibilityIdentifier("series.sort")
            if rows.isEmpty { StatePresentation(kind: .empty, title: "No series found", message: "Stored series remain available offline. Try another search or filter.") }
            LazyVStack(spacing: DesignTokens.Spacing.medium) {
                ForEach(rows, id: \.series.id) { detail in NavigationLink { SeriesPage(detailID: detail.series.id) } label: { SeriesListRow(detail: detail) }.buttonStyle(.plain) }
            }
        }.onAppear(perform: reload).onChange(of: model.version) { _,_ in reload() }
    }
    private func reload() { guard let repo = model.seriesRepository else { rows = []; return }; rows = (try? repo.series(query: query, filter: filter, sort: sort)) ?? [] }
}

private struct SeriesListRow: View {
    @Environment(\.colorScheme) private var scheme
    let detail: SeriesDetail
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) { identity; Spacer(minLength: 8); status }
                VStack(alignment: .leading, spacing: 8) { identity; status }
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                Text(totalLabel(detail)).foregroundStyle(DesignTokens.secondaryText(scheme))
                if detail.confirmedTotal > 0 { SeriesProgressBar(current: detail.readConfirmed, total: detail.confirmedTotal) }
            }
            if let next = detail.nextBook {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                    Text("NEXT BOOK").font(DesignTokens.functionalFont(size: 11, relativeTo: .caption, weight: .semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme))
                    Text(next.title).font(DesignTokens.functionalFont(size: 14, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }.padding(DesignTokens.Spacing.large)
            .background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
            .overlay { RoundedRectangle(cornerRadius: DesignTokens.cardRadius).stroke(DesignTokens.border(scheme), lineWidth: 1) }
            .accessibilityElement(children: .combine).accessibilityIdentifier("series.row.\(detail.series.id)")
    }
    @ViewBuilder private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(detail.series.name).font(DesignTokens.functionalFont(size: 19, relativeTo: .headline, weight: .semiBold)).fixedSize(horizontal: false, vertical: true)
            if let author = detail.series.author { Text(author).foregroundStyle(DesignTokens.secondaryText(scheme)) }
        }
    }
    private var status: some View {
        StatusChip(statusName(detail.series.effectiveStatus), symbol: statusSymbol(detail.series.effectiveStatus), tone: detail.series.effectiveStatus == .waiting ? .neutral : .active)
    }
}

private struct SeriesPage: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.colorScheme) private var scheme
    let detailID: UUID
    @State private var detail: SeriesDetail?
    @State private var reviews: [SeriesChangeProposal] = []
    var body: some View {
        BooksScreen("Series") {
            if let detail {
                Text(detail.series.name).font(DesignTokens.functionalFont(size: 28, relativeTo: .largeTitle, weight: .semiBold)).fixedSize(horizontal: false, vertical: true)
                if !reviews.isEmpty { StatusChip("Needs Attention", symbol: "exclamationmark.circle", tone: .special) }
                progressSection(detail)
                statusOverride(detail)
                if let next = detail.nextBook { nextBook(next) }
                tracker(detail)
                if !reviews.isEmpty { Text("Needs Attention").font(DesignTokens.functionalFont(size: 21, relativeTo: .title2, weight: .semiBold)); ForEach(reviews) { review in NavigationLink { SeriesReview(proposal: review, reload: reload) } label: { AttentionRow(title: "Review \(review.field.lowercased())", detail: "Current and proposed series information need your decision.", category: "Series") } } }
                Text("Timeline").font(DesignTokens.functionalFont(size: 21, relativeTo: .title2, weight: .semiBold))
                ForEach(detail.entries) { entry in SeriesTimelineRow(entry: entry, toggle: { included in _ = model.perform { try model.seriesRepository?.setTrackerInclusion(entryID: entry.id, included: included) }; reload() }) }
            }
            BooksErrorMessage()
        }.onAppear(perform: reload)
    }
    @ViewBuilder private func progressSection(_ detail: SeriesDetail) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text("PROGRESS").font(DesignTokens.functionalFont(size: 11, relativeTo: .caption, weight: .semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme))
            Text(totalLabel(detail)).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal: false, vertical: true)
            if detail.confirmedTotal > 0 { SeriesProgressBar(current: detail.readConfirmed, total: detail.confirmedTotal) }
        }.padding(.vertical, DesignTokens.Spacing.xSmall)
    }
    @ViewBuilder private func statusOverride(_ detail: SeriesDetail) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text("STATUS").font(DesignTokens.functionalFont(size: 11, relativeTo: .caption, weight: .semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme))
            StatusChip(statusName(detail.series.effectiveStatus), symbol: statusSymbol(detail.series.effectiveStatus), tone: detail.series.effectiveStatus == .waiting ? .neutral : .active)
            Text(detail.series.userStatusOverride == nil ? "Automatic from confirmed series information" : "User override")
                .font(DesignTokens.functionalFont(size: 13, relativeTo: .caption)).foregroundStyle(DesignTokens.secondaryText(scheme))
            Picker("Change series status", selection: Binding(get: { detail.series.userStatusOverride?.rawValue ?? "automatic" }, set: { value in _ = model.perform { try model.seriesRepository?.setStatusOverride(seriesID: detailID, status: value == "automatic" ? nil : SeriesStatus(rawValue: value)) }; reload() })) { Text("Automatic").tag("automatic"); ForEach([SeriesStatus.active,.waiting,.completed,.abandoned,.unknown], id: \.self) { Text(statusName($0)).tag($0.rawValue) } }.frame(minHeight: 44)
        }.padding(.vertical, DesignTokens.Spacing.xSmall)
    }
    @ViewBuilder private func nextBook(_ entry: SeriesEntry) -> some View { VStack(alignment: .leading, spacing: 8) { Text("Next Book").font(DesignTokens.functionalFont(size: 13, relativeTo: .caption, weight: .semiBold)); Text(entry.title).font(DesignTokens.functionalFont(size: 18, relativeTo: .headline, weight: .semiBold)); if let id = entry.bookID { NavigationLink("Open Next Book") { BookPageScreen(bookID: id) }.frame(minHeight: 44) } }.padding(16).background(DesignTokens.blueSurface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius)) }
    @ViewBuilder private func tracker(_ detail: SeriesDetail) -> some View { let map = detail.trackerMapping; VStack(alignment: .leading, spacing: 5) { Text("Physical Series Tracker").font(DesignTokens.functionalFont(size: 17, relativeTo: .headline, weight: .semiBold)); Text("\(map.type.rawValue) · \(map.entryCount) included entries"); if map.continuationPages > 0 { Text("Continuation required · \(map.continuationPages) additional section\(map.continuationPages == 1 ? "" : "s")") } }.padding(16).background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius)) }
    private func reload() { guard let repo = model.seriesRepository else { return }; detail = try? repo.seriesDetail(id: detailID); reviews = (try? repo.proposals(seriesID: detailID)) ?? [] }
}

private struct SeriesTimelineRow: View {
    @Environment(\.colorScheme) private var scheme
    let entry: SeriesEntry; let toggle: (Bool) -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(positionLabel(entry.position)).font(DesignTokens.functionalFont(size: 15, weight: .semiBold)).frame(minWidth: 38, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title).font(DesignTokens.functionalFont(size: 16, relativeTo: .headline, weight: .semiBold)).fixedSize(horizontal: false, vertical: true)
                ViewThatFits { HStack { labels }; VStack(alignment: .leading, spacing: 6) { labels } }
                Toggle("Include in physical tracker", isOn: Binding(get: { entry.includedInTracker }, set: toggle)).frame(minHeight: 44)
            }
        }.padding(.vertical, DesignTokens.Spacing.large).overlay(alignment: .bottom) { Divider() }.accessibilityElement(children: .contain)
    }
    @ViewBuilder private var labels: some View { StatusChip(entry.kind == .main ? "Main" : entry.kind == .related ? "Related" : "Companion", symbol: entry.kind == .main ? "book.closed" : "link"); StatusChip(entry.isRead ? "Read" : publicationLabel(entry), symbol: entry.isRead ? "checkmark" : "calendar", tone: entry.isRead ? .active : .neutral); Text(releaseLabel(entry.release)).foregroundStyle(DesignTokens.secondaryText(scheme)) }
}

private struct SeriesProgressBar: View {
    @Environment(\.colorScheme) private var scheme
    let current: Int
    let total: Int
    private var fraction: Double { total > 0 ? min(max(Double(current) / Double(total), 0), 1) : 0 }
    private var label: String { "\(current) of \(total) read" }
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(label).font(DesignTokens.functionalFont(size: 13, relativeTo: .caption, weight: .medium)).foregroundStyle(DesignTokens.secondaryText(scheme))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DesignTokens.border(scheme))
                    Capsule().fill(DesignTokens.primary(scheme)).frame(width: proxy.size.width * fraction)
                }
            }.frame(height: 10)
        }.accessibilityElement(children: .ignore).accessibilityLabel("Series progress").accessibilityValue(label).accessibilityIdentifier("series.progress")
    }
}

private struct SeriesReview: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.dismiss) private var dismiss
    let proposal: SeriesChangeProposal; let reload: () -> Void
    var body: some View { BooksScreen("Review Series Update") { DataChangeReview(field: proposal.field, current: proposal.current, proposed: proposal.proposed, source: proposal.source, accept: { _ = model.perform { try model.seriesRepository?.acceptProposal(id: proposal.id) }; reload(); dismiss() }, keep: { _ = model.perform { try model.seriesRepository?.rejectProposal(id: proposal.id) }; reload(); dismiss() }, edit: {}) } }
}

private func statusName(_ status: SeriesStatus) -> String { status.rawValue.capitalized }
private func statusSymbol(_ status: SeriesStatus) -> String { switch status { case .active: "book.pages"; case .waiting: "clock"; case .completed: "checkmark.circle"; case .abandoned: "xmark.circle"; case .unknown: "questionmark.circle" } }
private func totalLabel(_ detail: SeriesDetail) -> String { detail.series.finalTotalKnown ? "\(detail.confirmedTotal) confirmed entries" : "\(detail.confirmedTotal) confirmed entries · Final total unknown" }
private func positionLabel(_ value: Decimal) -> String { NSDecimalNumber(decimal: value).stringValue }
private func publicationLabel(_ entry: SeriesEntry) -> String { entry.publication.rawValue.capitalized }
private func releaseLabel(_ value: ReleaseValue) -> String { switch value { case .exact(let date): date.isoString; case .year(let year): String(year); case .unknown: "Release unknown" } }
