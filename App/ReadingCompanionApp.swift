import SwiftUI
import ReadingUI

@main
struct ReadingCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            FoundationShell().preferredColorScheme(acceptanceAppearance)
                .onAppear {
                    #if DEBUG
                    Phase0Diagnostics.shared.start()
                    #endif
                }
        }
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
