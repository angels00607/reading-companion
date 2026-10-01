import SwiftUI
import ReadingUI
import UIKit

@main
struct ReadingCompanionApp: App {
    init() {
        // UIKit owns native navigation/tab labels; use the approved functional font.
        let navigation = UINavigationBar.appearance()
        navigation.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: UIFont(name: "Manrope-SemiBold", size: 28)!)]
        navigation.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: UIFont(name: "Manrope-SemiBold", size: 17)!)]
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: UIFont(name: "Manrope-Medium", size: 11)!], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: UIFont(name: "Manrope-Medium", size: 11)!], for: .selected)
    }
    var body: some Scene { WindowGroup { FoundationShell() } }
}
