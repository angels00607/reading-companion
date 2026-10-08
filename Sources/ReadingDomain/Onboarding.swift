import Foundation

public enum OnboardingStep: String, Codable, CaseIterable, Sendable {
    case welcome
    case readingHistorySince
    case preferredEdition
    case importOrStartFresh
    case libraryReady
    case completed

    public var next: OnboardingStep {
        switch self {
        case .welcome: .readingHistorySince
        case .readingHistorySince: .preferredEdition
        case .preferredEdition: .importOrStartFresh
        case .importOrStartFresh: .libraryReady
        case .libraryReady, .completed: .completed
        }
    }
}

public enum PreferredEditionLanguage: String, Codable, CaseIterable, Sendable {
    case english = "en"
    case french = "fr"

    public var label: String { self == .english ? "English" : "French" }
}

public enum OnboardingLibraryChoice: String, Codable, Sendable {
    case storyGraphImport
    case startFresh
}

public struct OnboardingState: Codable, Equatable, Sendable {
    public var step: OnboardingStep
    public var readingHistorySince: Int?
    public var preferredEditionLanguage: PreferredEditionLanguage?
    public var libraryChoice: OnboardingLibraryChoice?
    public var completedAt: Date?

    public init(step: OnboardingStep = .welcome, readingHistorySince: Int? = nil,
                preferredEditionLanguage: PreferredEditionLanguage? = nil,
                libraryChoice: OnboardingLibraryChoice? = nil, completedAt: Date? = nil) {
        self.step = step
        self.readingHistorySince = readingHistorySince
        self.preferredEditionLanguage = preferredEditionLanguage
        self.libraryChoice = libraryChoice
        self.completedAt = completedAt
    }

    public var isComplete: Bool { step == .completed && completedAt != nil }
}

public enum OnboardingError: Error, Equatable, LocalizedError, Sendable {
    case invalidReadingHistoryYear
    case incompleteStep
    case importNotCompleted

    public var errorDescription: String? {
        switch self {
        case .invalidReadingHistoryYear: "Enter a valid four-digit year that is not in the future."
        case .incompleteStep: "Complete this step before continuing."
        case .importNotCompleted: "Finish the StoryGraph import, or choose Start Fresh."
        }
    }
}

public protocol OnboardingRepository: Sendable {
    func onboardingState() throws -> OnboardingState
    func saveOnboardingState(_ state: OnboardingState) throws
    func hasCompletedStoryGraphImport() throws -> Bool
    func completeOnboarding(_ state: OnboardingState) throws -> OnboardingState
}
