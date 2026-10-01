import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
                        .background(FullHeightTabBarConfiguration().frame(width: 0, height: 0))
                        .navigationTitle(tab.rawValue)
                }
                .tabItem { Label(tab.rawValue, systemImage: tab.symbol) }
            }
        }
        .tint(DesignTokens.primary(scheme))
    }
}

// UIKit owns the native bar geometry. A SwiftUI environment override does not
// change its compact-height traits; override only the bar, preserving content traits.
#if canImport(UIKit)
private struct FullHeightTabBarConfiguration: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ConfigurationController { ConfigurationController() }
    func updateUIViewController(_ controller: ConfigurationController, context: Context) { controller.configure() }

    final class ConfigurationController: UIViewController {
        private var configured = false
        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
            view.isAccessibilityElement = false
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configure()
        }
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            configure()
        }
        func configure() {
            guard !configured, let bar = tabBarController?.tabBar else { return }
            configured = true
            bar.traitOverrides.verticalSizeClass = .regular
            bar.setNeedsLayout()
            tabBarController?.view.setNeedsLayout()
        }
    }
}
#else
private struct FullHeightTabBarConfiguration: View {
    var body: some View { EmptyView() }
}
#endif
#Preview("Light") { FoundationShell().preferredColorScheme(.light) }
#Preview("Dark") { FoundationShell().preferredColorScheme(.dark) }