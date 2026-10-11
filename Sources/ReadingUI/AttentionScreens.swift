import SwiftUI
import ReadingDomain

public struct NeedsAttentionScreen: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.colorScheme) private var scheme
    @State private var filter: AttentionFilter = .all
    @State private var items = [AttentionItem]()
    @State private var loading = true
    @State private var error: String?
    @State private var warningPulse=0
    public init() {}
    public var body: some View {
        BooksScreen("Needs Attention") {
            Text("Review decisions that need your input. Nothing is changed until you choose an action.")
                .foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
            ScrollView(.horizontal,showsIndicators:false) {
                HStack { ForEach(AttentionFilter.allCases,id:\.self) { value in
                    FilterChip(value.rawValue,isSelected:Binding(get:{filter == value},set:{ selected in if selected { filter=value;load() }}))
                } }.padding(.vertical,2)
            }.accessibilityIdentifier("attention.filters")
            if loading { SkeletonRow() }
            else if let error { StatePresentation(kind:.error,title:"Attention items unavailable",message:error) }
            else if items.isEmpty { StatePresentation(kind:.empty,title:"Nothing needs attention",message:"Your saved reading data has no unresolved decisions in this category.") }
            else { ForEach(grouped,id:\.0) { category,rows in
                VStack(alignment:.leading,spacing:8) {
                    Text(category.label.uppercased()).font(DesignTokens.functionalFont(size:12,relativeTo:.caption,weight:.semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme))
                    ForEach(rows) { item in NavigationLink { destination(item) } label: {
                        AttentionRow(title:item.title,detail:item.detail,category:"\(item.category.label) · \(item.priority.rawValue.capitalized)")
                    }.buttonStyle(.plain).accessibilityIdentifier("attention.item."+item.id.uuidString) }
                }
            } }
        }.task(id:model.version) { load() }.accessibilityIdentifier("attention.screen").sensoryFeedback(.warning,trigger:warningPulse)
    }
    private var grouped:[(AttentionCategory,[AttentionItem])] {
        AttentionCategory.allCases.compactMap { category in let rows=items.filter{$0.category == category}; return rows.isEmpty ? nil : (category,rows) }
    }
    @ViewBuilder private func destination(_ item:AttentionItem) -> some View {
        switch item.category {
        case .journal: JournalCorrections()
        case .series: SeriesPage(detailID:item.entityID)
        case .challenges: BooksScreen("Challenge Review") { Text("Open Review Matches to inspect the recorded evidence and make this decision.").foregroundStyle(DesignTokens.secondaryText(scheme)); ChallengesHome() }
        case .books: BookPageScreen(bookID:item.entityID)
        case .import: ImportNeedsReview()
        }
    }
    private func load() {
        loading=true
        do { items=try model.attentionRepository?.unresolvedAttention(filter:filter) ?? [];error=nil;if !items.isEmpty && warningPulse == 0 {warningPulse=1} }
        catch { items=[];self.error="Saved data is unchanged. Try again." }
        loading=false
    }
}
