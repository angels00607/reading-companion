import SwiftUI

public enum MainTab: String, CaseIterable, Identifiable, Hashable {
    case home = "Home", journal = "Journal", challenges = "Challenges", series = "Series", stats = "Stats"
    public var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: "house"
        case .journal: "book"
        case .challenges: "checklist"
        case .series: "books.vertical"
        case .stats: "chart.bar"
        }
    }
}
public struct FoundationShell: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedTab: MainTab = .home
    @ScaledMetric(relativeTo: .body) private var navigationLabelSize: CGFloat = 11
    @ScaledMetric(relativeTo: .title3) private var navigationIconSize: CGFloat = 20
    public init() {}
    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(selectedTab.rawValue)
                    .font(DesignTokens.functionalFont(size: 28, relativeTo: .largeTitle, weight: .semiBold))
                    .foregroundStyle(DesignTokens.text(scheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("foundationTitle")
                Text("Foundation preview")
                    .font(DesignTokens.functionalFont(size: 16))
                    .foregroundStyle(DesignTokens.secondaryText(scheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(DesignTokens.background(scheme))
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .tint(DesignTokens.primary(scheme))
        .safeAreaInset(edge: .bottom, spacing: 0) { foundationTabBar }
    }

    private var foundationTabBar: some View {
        Group {
            if typeSize.isAccessibilitySize {
                ScrollView(.horizontal) {
                    tabButtons
                }
                .frame(height: max(56, navigationLabelSize * 1.6 + navigationIconSize + 16))
                .accessibilityIdentifier("foundationTabScroll")
            } else {
                tabButtons
            }
        }
        .background(DesignTokens.surface(scheme))
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")

    }

    private var tabButtons: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button { selectedTab = tab } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.title3)
                            .accessibilityHidden(true)
                        Text(tab.rawValue)
                            .font(DesignTokens.functionalFont(size: 11, relativeTo: .body,
                                weight: selectedTab == tab ? .semiBold : .medium))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: typeSize.isAccessibilitySize, vertical: true)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .frame(minWidth: DesignTokens.minimumTouchTarget, maxWidth: typeSize.isAccessibilitySize ? nil : .infinity,
                           minHeight: DesignTokens.minimumTouchTarget)
                    .contentShape(Rectangle())
                    .foregroundStyle(selectedTab == tab ? DesignTokens.primary(scheme) : DesignTokens.secondaryText(scheme))
                    .overlay(alignment: .top) {
                        if selectedTab == tab {
                            Rectangle().fill(DesignTokens.primary(scheme))
                                .frame(width: 24, height: 2).accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("foundationTab." + tab.rawValue)
            }
        }
        .padding(.horizontal, 8)

    }
}

#Preview("Light") { FoundationShell().preferredColorScheme(.light) }
#Preview("Dark") { FoundationShell().preferredColorScheme(.dark) }
