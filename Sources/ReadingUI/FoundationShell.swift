import SwiftUI

public enum MainTab: String, CaseIterable, Identifiable, Hashable {
    case home = "Home", journal = "Journal", challenges = "Challenges", series = "Series", stats = "Stats"
    public var id: String { rawValue }
    var symbol: String { switch self { case .home: "house"; case .journal: "book"; case .challenges: "checklist"; case .series: "books.vertical"; case .stats: "chart.bar" } }
}

public struct FoundationShell: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedTab: MainTab = .home
    private let homeContent: AnyView?
    private let journalContent: AnyView?
    private let challengesContent: AnyView?
    private let seriesContent: AnyView?
    public init() { homeContent = nil; journalContent = nil; seriesContent = nil; challengesContent = nil }
    public init(homeContent: AnyView, journalContent: AnyView? = nil, seriesContent: AnyView? = nil, challengesContent: AnyView? = nil) { self.homeContent = homeContent; self.journalContent = journalContent; self.seriesContent = seriesContent; self.challengesContent = challengesContent }
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let homeContent, selectedTab == .home { homeContent }
                    else if let journalContent, selectedTab == .journal { journalContent }
                    else if let challengesContent, selectedTab == .challenges { challengesContent }
                    else if let seriesContent, selectedTab == .series { seriesContent }
                    else { Phase1PreviewScreen(tab: selectedTab) }
                }
                    .padding(.horizontal, DesignTokens.margin).padding(.bottom, 24)
            }.background(DesignTokens.background(scheme)).scrollContentBackground(.hidden)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }.tint(DesignTokens.primary(scheme)).safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedTab.rawValue).font(DesignTokens.functionalFont(size: 28, relativeTo: .largeTitle, weight: .semiBold)).foregroundStyle(DesignTokens.text(scheme)).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader).accessibilityIdentifier("foundationTitle")
            if homeContent == nil { Text("Phase 1 component preview data").font(DesignTokens.functionalFont(size: 13, relativeTo: .caption, weight: .medium)).foregroundStyle(DesignTokens.secondaryText(scheme)) }
        }.padding(.top, 8)
    }
    private var tabBar: some View {
        tabButtons
            .background(DesignTokens.surface(scheme)).overlay(alignment: .top) { Divider() }
            .accessibilityElement(children: .contain).accessibilityLabel("Main navigation")
    }
    private var tabButtons: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button { selectedTab = tab } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol).font(.system(size: 20)).frame(width: 40, height: 36)
                            .background(selectedTab == tab ? DesignTokens.blueSurface(scheme) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityHidden(true)
                        if !typeSize.isAccessibilitySize {
                            Text(tab.rawValue).font(DesignTokens.functionalFont(size: 11, relativeTo: .body, weight: selectedTab == tab ? .semiBold : .medium)).multilineTextAlignment(.center)
                        }
                    }.padding(.vertical, 6).padding(.horizontal, 4).frame(minWidth: 44, maxWidth: typeSize.isAccessibilitySize ? nil : .infinity, minHeight: 44).contentShape(Rectangle()).foregroundStyle(selectedTab == tab ? DesignTokens.primary(scheme) : DesignTokens.secondaryText(scheme)).overlay(alignment: .top) { if selectedTab == tab { Rectangle().fill(DesignTokens.primary(scheme)).frame(width: 24, height: 2).accessibilityHidden(true) } }
                }.buttonStyle(.plain).accessibilityLabel(tab.rawValue).accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton).accessibilityIdentifier("foundationTab." + tab.rawValue)
            }
        }.padding(.horizontal, 8).frame(maxWidth: .infinity)
    }
}

private struct Phase1PreviewScreen: View {
    @Environment(\.colorScheme) private var scheme
    let tab: MainTab
    @State private var selectedFilter = true
    @State private var segment = "Recent"
    private let book = PreviewBook(id: "preview-book", title: "A Deliberately Long Book Title for Responsive Layout Testing", author: "Preview Author Name", coverSymbol: "bookmark", detail: "Preview data · Currently reading")
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch tab { case .home: home; case .journal: journal; case .challenges: challenges; case .series: series; case .stats: stats }
        }.foregroundStyle(DesignTokens.text(scheme))
    }
    private var home: some View {
        Group {
            BookRow(book: book); StatusChip("Currently reading", symbol: "book.pages", tone: .active); ReadingProgressBar(.pages(current: 187, total: 450))
            HStack { AppButton("Primary", symbol: "plus", action: {}); AppButton("Secondary", kind: .secondary, action: {}) }
            AppToast("Preview change saved", actionTitle: "Undo", action: {})
        }
    }
    private var journal: some View {
        Group {
            Text("Journal accent preview").font(DesignTokens.journalAccent(size: 21)).accessibilityLabel("Journal accent preview")
            AppBottomSheet(title: "Preview sheet") { VStack(spacing: 12) { StatusChip("Ready to journal", symbol: "checkmark", tone: .special); AppButton("Done", action: {}) } }
            SkeletonRow(); StatePresentation(kind: .empty, title: "Nothing ready yet", message: "Completed journal preparation will appear here.")
        }
    }
    private var challenges: some View {
        Group {
            ViewThatFits(in: .horizontal) {
                HStack { filterChips }
                VStack(alignment: .leading, spacing: 8) { filterChips }
            }
            AppSegmentedControl(options: [("Recent", "Recent"), ("All", "All")], selection: $segment)
            DataChangeReview(field: "Preview field", current: "Current preview value", proposed: "Proposed preview value", source: "Preview source")
        }
    }
    @ViewBuilder private var filterChips: some View {
        FilterChip("Selected", isSelected: $selectedFilter)
        FilterChip("Unselected", isSelected: Binding(get: { !selectedFilter }, set: { selectedFilter = !$0 }))
    }
    private var series: some View {
        Group {
            OfflineBanner(); AttentionRow(title: "Review preview change", detail: "A sample external change is waiting for a decision.", category: "Series · Preview data")
            StatePresentation(kind: .error, title: "Could not refresh preview", message: "Existing local data has not changed.")
            StatePresentation(kind: .offline, title: "External data unavailable", message: "Cached and local content remains available.")
        }
    }
    private var stats: some View {
        Group {
            AccessibleBarChart(title: "Preview chart", data: [.init("Jan", value: 3), .init("Feb", value: 5), .init("Mar", value: 2)])
            FeatureCelebration(eyebrow: "PREVIEW", title: "A reading moment", message: "Reusable celebration structure without reward or completion logic.")
        }
    }
}

struct FoundationShell_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FoundationShell().preferredColorScheme(.light).previewDisplayName("Light")
            FoundationShell().preferredColorScheme(.dark).previewDisplayName("Dark")
            FoundationShell().environment(\.dynamicTypeSize, .accessibility3)
                .previewLayout(.fixed(width: 320, height: 700)).previewDisplayName("Compact accessibility")
        }
    }
}
