import SwiftUI
import ReadingUI
import UIKit

@main
struct ReadingCompanionApp: App {
    init() {
        // UIKit owns native navigation titles; use the approved functional font.
        let navigation = UINavigationBar.appearance()
        navigation.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: UIFont(name: "Manrope-SemiBold", size: 28)!)]
        navigation.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: UIFont(name: "Manrope-SemiBold", size: 17)!)]
    }
    var body: some Scene {
        WindowGroup { FoundationShell().preferredColorScheme(acceptanceAppearance) }
    }

    private var acceptanceAppearance: ColorScheme? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-phase0-appearance"), index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "Dark": return .dark
            case "Light": return .light
            default: break
            }
        }
        #endif
        return nil // Normal launches and Release builds follow the system.
    }
}
