import SwiftUI
import ReadingUI

/// Native macOS shell. The existing iPhone application and its data remain untouched.
@main
struct ReadingCompanionMacApp: App {
    var body: some Scene {
        WindowGroup("Reading Companion") {
            FoundationShell()
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 1100, height: 760)
    }
}
