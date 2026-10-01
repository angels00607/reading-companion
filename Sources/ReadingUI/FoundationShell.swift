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
    @State private var selectedTab: MainTab = .home
    public init() {}
    public var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(MainTab.allCases) { tab in
                NavigationStack {
                    Text("Foundation preview")
                        .font(DesignTokens.functionalFont(size: 16))
                        .foregroundStyle(DesignTokens.secondaryText(scheme))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DesignTokens.background(scheme))
                        .navigationTitle(tab.rawValue)
                }
                .tabItem { Label(tab.rawValue, systemImage: tab.symbol) }
                .tag(tab)
                .hideFoundationNativeTabBar()
            }
        }
        .tint(DesignTokens.primary(scheme))
        .safeAreaInset(edge: .bottom, spacing: 0) { foundationTabBar }
    }

    private var foundationTabBar: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button { selectedTab = tab } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 20))
                        Text(tab.rawValue)
                            .font(DesignTokens.functionalFont(size: 11, relativeTo: .caption2,
                                weight: selectedTab == tab ? .semiBold : .medium))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .frame(minWidth: DesignTokens.minimumTouchTarget, maxWidth: .infinity,
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("foundationTab." + tab.rawValue)
            }
        }
        .padding(.horizontal, 8)
        .background(DesignTokens.surface(scheme))
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }
}

private extension View {
    @ViewBuilder func hideFoundationNativeTabBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .tabBar)
        #else
        self
        #endif
    }
}
#Preview("Light") { FoundationShell().preferredColorScheme(.light) }
#Preview("Dark") { FoundationShell().preferredColorScheme(.dark) }