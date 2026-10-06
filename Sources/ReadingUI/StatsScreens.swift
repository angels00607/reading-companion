import SwiftUI
import ReadingDomain

public struct StatsHome: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var scope: String
    @State private var year: Int
    @State private var month: Int
    @State private var journal: Bool
    @State private var volumeStart: Int
    @State private var snapshot: StatsSnapshot?
    @State private var choosePeriod=false
    public init(period: StatsPeriod? = nil, journal: Bool = false, volumeStart: Int? = nil) {
        let p=period ?? .month(year:BooksModel.today.year,month:BooksModel.today.month)
        _scope=State(initialValue:p.selectionScope == "month" ? "Month" : p.selectionScope == "year" ? "Year" : "Lifetime")
        _year=State(initialValue:p.year ?? BooksModel.today.year)
        if case let .month(_,m)=p { _month=State(initialValue:m) } else { _month=State(initialValue:BooksModel.today.month) }
        _journal=State(initialValue:journal); _volumeStart=State(initialValue:volumeStart ?? min(9995,BooksModel.today.year))
    }
    private var period: StatsPeriod {
        switch scope { case "Month": .month(year:year,month:month); case "Year": .year(year); default: journal ? .volume(startYear:volumeStart) : .lifetime }
    }
    public var body: some View {
        VStack(alignment:.leading,spacing:24) {
            modeControls
            scopeControls
            if scope != "Lifetime" || journal {
                Button { choosePeriod=true } label: {
                    HStack(alignment:.top) {
                        Text(periodTitle).fixedSize(horizontal:false,vertical:true)
                        Spacer(minLength:12); Image(systemName:"calendar").accessibilityHidden(true)
                    }.frame(maxWidth:.infinity,minHeight:44,alignment:.leading).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(DesignTokens.primary(scheme)).accessibilityIdentifier("stats.period")
            } else { Text("All your reading history").foregroundStyle(DesignTokens.secondaryText(scheme)) }
            if let s=snapshot {
                if journal { journalSummary(s) } else { readingSummary(s) }
                if scope != "Lifetime" { bestBook(s) }
                if !journal {
                    NavigationLink { StatsReadingsScreen(period:period) } label: { statsLinkLabel("Books & reading details") }
                        .buttonStyle(.plain).accessibilityIdentifier("stats.readings")
                }
            } else { SkeletonRow() }
            BooksErrorMessage()
        }.font(DesignTokens.functionalFont(size:16)).foregroundStyle(DesignTokens.text(scheme))
            .onAppear(perform:reload).onChange(of:period) { _,_ in reload() }.onChange(of:model.version) { _,_ in reload() }
            .sheet(isPresented:$choosePeriod) { StatsPeriodPicker(year:$year,month:$month,volumeStart:$volumeStart,scope:scope,journal:journal) }
    }
    private var periodTitle: String {
        switch period {
        case let .month(y,m): "\(DateFormatter().monthSymbols[m-1]) \(String(y))"
        case let .year(y): String(y)
        case let .volume(y): "\(String(y))–\(String(y+4)) · five-year view"
        case .lifetime: "Lifetime"
        }
    }
    private var modeControls: some View {
        VStack(alignment:.leading,spacing:8) {
            Text(journal ? "Prepared for your physical journal" : "Your reading, in perspective")
                .font(DesignTokens.functionalFont(size:14)).foregroundStyle(DesignTokens.secondaryText(scheme))
            Button { journal.toggle(); reload() } label: {
                Label(journal ? "Switch to Reading Stats" : "Switch to Journal View",systemImage:journal ? "chart.bar" : "book")
                    .fixedSize(horizontal:false,vertical:true).padding(.vertical,8).frame(maxWidth:.infinity,minHeight:44,alignment:.leading).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(DesignTokens.primary(scheme)).accessibilityIdentifier("stats.mode")
        }
    }
    @ViewBuilder private var scopeControls: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment:.leading,spacing:4) { ForEach(["Month","Year","Lifetime"],id:\.self) { name in scopeButton(name) } }
        } else { HStack(spacing:8) { ForEach(["Month","Year","Lifetime"],id:\.self) { name in scopeButton(name) } } }
    }
    private func scopeButton(_ name:String) -> some View {
        Button { scope=name; reload() } label: {
            HStack { if scope==name { Image(systemName:"checkmark").accessibilityHidden(true) }; Text(name).fixedSize(horizontal:false,vertical:true) }
                .font(DesignTokens.functionalFont(size:14,weight:scope==name ? .semiBold : .medium))
                .padding(10).frame(maxWidth:.infinity,minHeight:44,alignment:.leading).contentShape(Rectangle())
                .background(scope==name ? DesignTokens.blueSurface(scheme) : Color.clear,in:RoundedRectangle(cornerRadius:10))
        }.buttonStyle(.plain).accessibilityAddTraits(scope==name ? .isSelected : []).accessibilityIdentifier("stats.scope."+name)
    }
    private func readingSummary(_ s:StatsSnapshot) -> some View {
        VStack(alignment:.leading,spacing:28) {
            VStack(alignment:.leading,spacing:4) {
                Text(s.books.formatted()).font(DesignTokens.functionalFont(size:36,relativeTo:.largeTitle,weight:.semiBold)).foregroundStyle(DesignTokens.primary(scheme)).accessibilityIdentifier("stats.books.value")
                Text("Books Read").font(DesignTokens.functionalFont(size:20,relativeTo:.title2,weight:.semiBold))
                Text("Each completed reading counts, including rereads.").font(DesignTokens.functionalFont(size:13)).foregroundStyle(DesignTokens.secondaryText(scheme))
                if s.rereads>0 { Text("\(s.rereads) repeat reading\(s.rereads==1 ? "" : "s")").font(DesignTokens.functionalFont(size:14)) }
                if s.undatedCompletions>0 && period != .lifetime { Text("\(s.undatedCompletions) completed reading\(s.undatedCompletions==1 ? " has" : "s have") no finish date; no period is assumed.").font(DesignTokens.functionalFont(size:13)).foregroundStyle(DesignTokens.secondaryText(scheme)) }
            }
            StatsMetric(title:"Pages Read",value:s.pages.display,detail:pageDetail(s),id:"stats.pages")
            StatsMetric(title:"Reading Days",value:s.readingDays.display,detail:"Only explicitly recorded reading dates count. Missing daily history stays unknown; dates are never spread across a reading interval.",id:"stats.days")
            StatsMetric(title:"Average Rating",value:s.averageRating.map { String(format:"%.1f",$0)+" / 5" } ?? "Unavailable",
                detail:"\(s.ratedCount) rated · \(s.noRatingCount) No Rating · \(s.unknownRatingCount) unknown. No Rating is excluded from the average.",id:"stats.rating")
            StatsDistribution(title:"Primary Genres",values:s.genres)
            StatsDistribution(title:"Formats",values:s.formats)
            StatsTimeline(snapshot:s)
        }
    }
    private func pageDetail(_ s:StatsSnapshot) -> String {
        "Genuine resolved page updates only. \(s.pages.coveredReadings) of \(s.pages.totalReadings) completed readings have page observations. Percentage and edition page counts are never converted into pages read." + (s.pages.complete ? "" : " Recorded subtotal; coverage is incomplete.")
    }
    private func journalSummary(_ s:StatsSnapshot) -> some View {
        VStack(alignment:.leading,spacing:20) {
            Text("Journal View · \(scope)").font(DesignTokens.functionalFont(size:24,relativeTo:.title2,weight:.semiBold)).accessibilityIdentifier("stats.journal.title")
            Text(scope=="Month" ? "Monthly double page" : scope=="Year" ? "Yearly statistics · two pages" : "Lifetime statistics · five-year volume")
                .font(DesignTokens.functionalFont(size:14)).foregroundStyle(DesignTokens.secondaryText(scheme))
            if scope=="Lifetime" { Text("Choose the five years that match your physical volume. This view does not assign or archive a volume for you.").font(DesignTokens.functionalFont(size:14)) }
            if s.undatedCompletions>0 { Text("\(s.undatedCompletions) completed reading\(s.undatedCompletions==1 ? " has" : "s have") no finish date and cannot be assigned to these physical pages.").font(DesignTokens.functionalFont(size:14)).foregroundStyle(DesignTokens.secondaryText(scheme)) }
            VStack(alignment:.leading,spacing:20) {
                StatsMetric(title:"Books Read",value:s.books.formatted(),detail:"Completed readings, including rereads. DNF excluded.",id:"stats.books")
                StatsMetric(title:"Pages Read",value:s.pages.display,detail:pageDetail(s),id:"stats.pages")
                StatsMetric(title:"Reading Days",value:s.readingDays.display,detail:"Recorded dates only; missing historical activity remains unknown.",id:"stats.days")
                StatsMetric(title:"Average Rating",value:s.averageRating.map { String(format:"%.1f",$0)+" / 5" } ?? "Unavailable",detail:"No Rating is not zero.",id:"stats.rating")
                StatsDistribution(title:"Primary Genres",values:s.genres)
                StatsDistribution(title:"Formats",values:s.formats)
            }.padding(16).background(DesignTokens.surface(scheme),in:RoundedRectangle(cornerRadius:14))
            if scope=="Lifetime" {
                ForEach(volumeStart...(volumeStart+4),id:\.self) { y in
                    let annual=StatsRules.snapshot(period:.year(y),readings:s.allReadings,selections:s.selections)
                    VStack(alignment:.leading,spacing:8) {
                        Text(String(y)).font(DesignTokens.functionalFont(size:20,relativeTo:.title2,weight:.semiBold)).accessibilityIdentifier("stats.journal.year.\(y)")
                        Text("\(annual.books) Books Read")
                        Text("Pages Read: \(annual.pages.display)")
                        Text("Reading Days: \(annual.readingDays.display)")
                        Text("Book of Year: \(annual.selection?.readingID == nil ? "Not selected" : annual.selected?.title ?? "Selection retained · book unavailable")").fixedSize(horizontal:false,vertical:true)
                        if annual.selectionNeedsReview { Text("Book of Year choice needs review; preserved unchanged.") }
                    }.padding(.vertical,12).overlay(alignment:.bottom) { DesignTokens.border(scheme).frame(height:1) }
                }
            }
            Text("Copy the recorded values and their coverage notes. Unknown is a valid entry; there is no duplicate data entry here.").font(DesignTokens.functionalFont(size:14)).foregroundStyle(DesignTokens.secondaryText(scheme))
        }
    }
    private func bestBook(_ s:StatsSnapshot) -> some View {
        VStack(alignment:.leading,spacing:16) {
            Text(scope=="Month" ? "Best Book of the Month" : "Book of Year").font(DesignTokens.functionalFont(size:22,relativeTo:.title2,weight:.semiBold)).accessibilityAddTraits(.isHeader)
            if let selected=s.selected {
                VStack(alignment:.leading,spacing:12) {
                    BookCover(title:selected.title,width:84,url:model.coverURL(selected.coverReference))
                    Text(selected.title).font(DesignTokens.functionalFont(size:20,relativeTo:.headline,weight:.semiBold)).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("stats.best.title")
                    Text(selected.author).foregroundStyle(DesignTokens.secondaryText(scheme))
                    Text("Your choice").foregroundStyle(DesignTokens.secondary(scheme))
                }
            } else { Text(s.selection?.readingID == nil ? "Not selected" : "Selection retained · book unavailable").accessibilityIdentifier("stats.best.empty") }
            if s.selectionNeedsReview { Text("Review your choice: this reading is no longer eligible. Your selection has been preserved.").foregroundStyle(DesignTokens.secondary(scheme)).accessibilityIdentifier("stats.best.review") }
            Text(scope=="Month" ? "Choose from this month’s completed readings. There is no automatic winner." : "Candidates are your eligible monthly Best Books. The yearly choice is also yours.")
                .font(DesignTokens.functionalFont(size:14)).foregroundStyle(DesignTokens.secondaryText(scheme))
            NavigationLink { StatsBestBookPicker(period:period) } label: { statsLinkLabel(s.selection?.readingID == nil ? "Choose a book" : "Review or change choice") }
                .buttonStyle(.plain).accessibilityIdentifier("stats.best.choose")
        }.padding(.top,8)
    }
    private func reload() {
        do { snapshot=try model.statsRepository?.stats(period:period) }
        catch { model.error="Could not load Stats. Your saved reading data has not changed." }
    }
}

struct StatsMetric: View {
    @Environment(\.colorScheme) private var scheme
    let title:String; let value:String; let detail:String; let id:String
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            Text(title).font(DesignTokens.functionalFont(size:17,relativeTo:.headline,weight:.semiBold)).accessibilityAddTraits(.isHeader)
            Text(value).font(DesignTokens.functionalFont(size:26,relativeTo:.title2,weight:.semiBold)).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier(id+".value")
            Text(detail).font(DesignTokens.functionalFont(size:13)).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}
private struct StatsDistribution: View {
    @Environment(\.colorScheme) private var scheme
    let title:String; let values:[StatsCategory]
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text(title).font(DesignTokens.functionalFont(size:20,relativeTo:.title2,weight:.semiBold)).accessibilityAddTraits(.isHeader)
            if values.isEmpty { Text("No completed readings").foregroundStyle(DesignTokens.secondaryText(scheme)) }
            ForEach(values) { item in
                HStack(alignment:.top,spacing:12) {
                    Text(item.label).fixedSize(horizontal:false,vertical:true); Spacer(minLength:8)
                    Text(item.count.formatted()).font(DesignTokens.functionalFont(size:16,weight:.semiBold)).fixedSize()
                }.padding(.vertical,6).overlay(alignment:.bottom) { DesignTokens.border(scheme).frame(height:1) }
                    .accessibilityElement(children:.ignore).accessibilityLabel("\(title), \(item.label), \(item.count) completed readings")
            }
        }
    }
}
private struct StatsTimeline: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    let snapshot:StatsSnapshot
    private var visible:[StatsTimePoint] {
        // Month chart shows only dates with actual finishes; no implied daily page/activity history.
        if case .month=snapshot.period { return snapshot.time.filter { ($0.count ?? 0)>0 } }
        return snapshot.time
    }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text("Reading over time").font(DesignTokens.functionalFont(size:20,relativeTo:.title2,weight:.semiBold)).accessibilityAddTraits(.isHeader)
            Text(snapshot.period.selectionScope == "month" ? "Books finished · calendar day" : "Books finished · calendar period")
                .font(DesignTokens.functionalFont(size:14)).foregroundStyle(DesignTokens.secondaryText(scheme))
            if visible.isEmpty { Text("No dated completions to chart") }
            let maximum=Double(max(1,visible.compactMap(\.count).max() ?? 1))
            ForEach(visible) { point in
                VStack(alignment:.leading,spacing:6) {
                    HStack(alignment:.top) { Text(point.label); Spacer(); Text(point.count.map(String.init) ?? "Unknown").fixedSize(horizontal:false,vertical:true) }
                    if let count=point.count {
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius:3).fill(DesignTokens.primary(scheme))
                                .frame(width:geometry.size.width * Double(count)/maximum,height:6)
                        }.frame(height:6).accessibilityHidden(true)
                    }
                }.padding(.vertical,typeSize.isAccessibilitySize ? 8 : 2).accessibilityElement(children:.ignore)
                    .accessibilityLabel("\(point.label), \(point.count.map { "\($0) books finished" } ?? "Unknown")")
            }
            if snapshot.undatedCompletions>0 { Text("\(snapshot.undatedCompletions) undated completions are not placed on the chart. Known counts are recorded subtotals; empty periods cannot establish zero.").font(DesignTokens.functionalFont(size:13)).foregroundStyle(DesignTokens.secondaryText(scheme)) }
        }.accessibilityIdentifier("stats.chart")
    }
}
@MainActor private func statsLinkLabel(_ title:String) -> some View {
    HStack(alignment:.top) { Text(title).fixedSize(horizontal:false,vertical:true); Spacer(minLength:8); Image(systemName:"chevron.right").accessibilityHidden(true) }
        .padding(.vertical,10).frame(maxWidth:.infinity,minHeight:44,alignment:.leading).contentShape(Rectangle())
}
private struct StatsPeriodPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var year:Int; @Binding var month:Int; @Binding var volumeStart:Int
    let scope:String; let journal:Bool
    @State private var yearText=""
    var body:some View {
        NavigationStack {
            BooksScreen("Choose period") {
                BooksField(label:scope=="Lifetime" ? "First year of five-year view" : "Year",value:$yearText)
                if scope=="Month" {
                    ForEach(1...12,id:\.self) { m in AppButton(DateFormatter().monthSymbols[m-1],kind:month==m ? .primary : .secondary) { month=m }.accessibilityIdentifier("stats.month.\(m)") }
                }
                AppButton("Use period") {
                    if let y=Int(yearText),(1...(scope=="Lifetime" ? 9995 : 9999)).contains(y) { if scope=="Lifetime" { volumeStart=y } else { year=y }; dismiss() }
                }.disabled(Int(yearText).map { !(1...(scope=="Lifetime" ? 9995 : 9999)).contains($0) } ?? true)
            }.onAppear { yearText=String(scope=="Lifetime" ? volumeStart : year) }
        }
    }
}
struct StatsBestBookPicker: View {
    @EnvironmentObject private var model:BooksModel
    let period:StatsPeriod
    @State private var snapshot:StatsSnapshot?
    var body:some View {
        BooksScreen(period.selectionScope=="month" ? "Choose Best Book" : "Choose Book of Year") {
            Text("Select a completed reading. Ratings never choose a winner for you.").fixedSize(horizontal:false,vertical:true)
            if let s=snapshot {
                if s.candidates.isEmpty { Text(period.selectionScope=="year" ? "No eligible monthly Best Books selected yet." : "No eligible completed readings in this month.") }
                ForEach(s.candidates) { r in
                    Button { save(r.id,s) } label: {
                        VStack(alignment:.leading,spacing:8) {
                            Text(r.title).font(DesignTokens.functionalFont(size:17,relativeTo:.headline,weight:.semiBold)).fixedSize(horizontal:false,vertical:true)
                            Text(r.finish?.isoString ?? "Unknown finish date").font(DesignTokens.functionalFont(size:14))
                            if r.id==s.selection?.readingID { Label("Selected",systemImage:"checkmark") }
                        }.padding(.vertical,12).frame(maxWidth:.infinity,minHeight:44,alignment:.leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("stats.candidate."+r.id.uuidString).accessibilityAddTraits(r.id==s.selection?.readingID ? .isSelected : [])
                }
                if s.selection?.readingID != nil { AppButton("Clear choice",kind:.secondary) { save(nil,s) }.accessibilityIdentifier("stats.best.clear") }
            }
            BooksErrorMessage()
        }.onAppear(perform:reload)
    }
    private func save(_ id:UUID?,_ s:StatsSnapshot) { _=model.perform { try model.statsRepository?.selectBestBook(period:period,readingID:id,expectedRevision:s.selection?.revision ?? 0) }; reload() }
    private func reload() { snapshot=try? model.statsRepository?.stats(period:period) }
}
struct StatsReadingsScreen: View {
    @EnvironmentObject private var model:BooksModel
    let period:StatsPeriod
    @State private var snapshot:StatsSnapshot?
    var body:some View {
        BooksScreen("Completed readings") {
            if let s=snapshot {
                Text("\(s.books) completed readings · rereads remain separate")
                ForEach(s.readings) { r in
                    NavigationLink { ReadingHistoryScreen(bookID:r.bookID) } label: {
                        VStack(alignment:.leading,spacing:6) {
                            Text(r.title).font(DesignTokens.functionalFont(size:17,relativeTo:.headline,weight:.semiBold)).fixedSize(horizontal:false,vertical:true)
                            Text(r.finish?.isoString ?? "Unknown finish date")
                            Text(r.genre ?? "Unknown Primary Genre")
                            Text(r.format?.rawValue.capitalized ?? "Unknown Format")
                            Text(r.observedPages.map { "\($0) recorded pages" } ?? "Pages unknown")
                        }.padding(.vertical,12).frame(maxWidth:.infinity,minHeight:44,alignment:.leading).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            Text("Open Reading History to correct dates, rating, Primary Genre or user-selected Format.").font(DesignTokens.functionalFont(size:14))
        }.onAppear { snapshot=try? model.statsRepository?.stats(period:period) }.onChange(of:model.version) { _,_ in snapshot=try? model.statsRepository?.stats(period:period) }
    }
}

public struct StatsVisualQA: View {
    let route:String
    public init(route:String) { self.route=route }
    public var body:some View {
        #if DEBUG
        NavigationStack {
            if route=="year-candidates" { StatsBestBookPicker(period:.year(2026)) }
            else if route=="readings" { StatsReadingsScreen(period:.lifetime) }
            else {
                BooksScreen("Stats") {
                    StatsHome(period:route.contains("year") ? .year(2026) : route.contains("lifetime") ? .lifetime : route=="unknown" ? .month(year:2025,month:12) : .month(year:2026,month:9),journal:route.hasPrefix("journal"),volumeStart:2026)
                }
            }
        }
        #else
        EmptyView()
        #endif
    }
}
