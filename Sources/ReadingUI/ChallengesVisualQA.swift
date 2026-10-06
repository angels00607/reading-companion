import SwiftUI
import ReadingDomain

/// Opt-in fixture routes are compiled out of Release and use the real screen/repository.
public struct ChallengesVisualQA: View {
    let route: String
    public init(route: String) { self.route = route }
    public var body: some View {
        #if DEBUG
        NavigationStack {
            if route == "overview" { BooksScreen("Challenges") { ChallengesHome(year: 2027) } }
            else if route == "no-information" { ChallengeReviewScreen(year: 2028) }
            else if route == "review" { ChallengeReviewScreen(year: 2027) }
            else if route == "archive" { ChallengeArchive() }
            else if route == "2028" { BooksScreen("Challenges") { ChallengesHome(year: 2028) } }
            else if let kind = ChallengeKind(rawValue: route) { ChallengeDetailScreen(year: 2027, kind: kind) }
            else { BooksScreen("Challenge Archive") { ChallengesHome(year: 2026) } }
        }
        #else
        EmptyView()
        #endif
    }
}
