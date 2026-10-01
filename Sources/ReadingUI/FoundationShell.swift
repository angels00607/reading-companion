import SwiftUI

public enum MainTab: String, CaseIterable, Identifiable {
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
    public init() {}
    public var body: some View {
        TabView {
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
            }
        }
        .tint(DesignTokens.primary(scheme))
    }
}
#Preview("Light") { FoundationShell().preferredColorScheme(.light) }
#Preview("Dark") { FoundationShell().preferredColorScheme(.dark) }
