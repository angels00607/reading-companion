import SwiftUI
import ReadingDomain

public struct OnboardingFlow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var model: BooksModel
    @State private var state: OnboardingState
    @State private var yearText: String
    @State private var error: String?
    @State private var importCompleted = false
    private let onComplete: (OnboardingState) -> Void

    public init(state: OnboardingState, onComplete: @escaping (OnboardingState) -> Void) {
        _state = State(initialValue: state)
        _yearText = State(initialValue: state.readingHistorySince.map(String.init) ?? "")
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    progress
                    content
                    if let error { StatePresentation(kind: .error, title: "Could not continue", message: error) }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(.horizontal, DesignTokens.margin)
                .padding(.vertical, 24)
            }
            .background(DesignTokens.background(scheme).ignoresSafeArea())
            .tint(DesignTokens.primary(scheme))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: state.step)
            .task(id: model.version) { refreshImportStatus() }
        }
    }

    private var progress: some View {
        let index = max(0, OnboardingStep.allCases.firstIndex(of: state.step) ?? 0)
        return VStack(alignment: .leading, spacing: 8) {
            Text("SET UP READING COMPANION")
                .font(DesignTokens.functionalFont(size: 12, relativeTo: .caption, weight: .semiBold))
                .foregroundStyle(DesignTokens.secondaryText(scheme))
            ProgressView(value: Double(min(index + 1, 5)), total: 5)
                .tint(DesignTokens.primary(scheme))
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("Step \(min(index + 1, 5)) of 5")
        }
    }

    @ViewBuilder private var content: some View {
        switch state.step {
        case .welcome: welcome
        case .readingHistorySince: readingHistory
        case .preferredEdition: preferredEdition
        case .importOrStartFresh: importOrFresh
        case .libraryReady: libraryReady
        case .completed: libraryReady
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "books.vertical.fill").font(.system(size: 44)).foregroundStyle(DesignTokens.primary(scheme)).accessibilityHidden(true)
            title("Welcome to Reading Companion")
            Text("Keep your library, reading progress, and physical journal preparation together—without turning reading into a chore.")
                .font(DesignTokens.functionalFont(size: 17, relativeTo: .body)).fixedSize(horizontal: false, vertical: true)
            AppButton("Set up my library", symbol: "arrow.right", action: { advance(to: .readingHistorySince) })
                .accessibilityIdentifier("onboarding.welcome.continue")
        }
    }

    private var readingHistory: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("When did your reading history begin?")
            Text("Use the earliest year you want Reading Companion to represent. This is not your account creation date.")
                .foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal: false, vertical: true)
            TextField("Year, for example 2020", text: $yearText)
                .font(DesignTokens.functionalFont(size: 17)).textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .accessibilityLabel("Reading history start year")
                .accessibilityIdentifier("onboarding.readingSince")
            AppButton("Continue", action: saveYear).accessibilityIdentifier("onboarding.readingSince.continue")
            back(to: .welcome)
        }
    }

    private var preferredEdition: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("Which edition language do you prefer?")
            Text("This preference changes catalogue ordering only. Reading Companion still shows only real editions returned by the catalogue.")
                .foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal: false, vertical: true)
            ForEach(PreferredEditionLanguage.allCases, id: \.self) { language in
                Button { chooseLanguage(language) } label: {
                    HStack {
                        Text(language.label).font(DesignTokens.functionalFont(size: 17, weight: .semiBold))
                        Spacer()
                        Image(systemName: state.preferredEditionLanguage == language ? "checkmark.circle.fill" : "circle")
                    }.frame(minHeight: 48).padding(.horizontal, 16)
                        .background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityAddTraits(state.preferredEditionLanguage == language ? .isSelected : [])
                    .accessibilityIdentifier("onboarding.edition.\(language.rawValue)")
            }
            AppButton("Continue", action: { advance(to: .importOrStartFresh) })
                .disabled(state.preferredEditionLanguage == nil).accessibilityIdentifier("onboarding.edition.continue")
            back(to: .readingHistorySince)
        }
    }

    private var importOrFresh: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("Bring your library—or start fresh")
            Text("A StoryGraph CSV can add historical reading data. Historical imports never create XP, Achievements, Quests, automatic Challenges, or Journal Inbox work.")
                .foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal: false, vertical: true)
            NavigationLink {
                ImportHome()
            } label: {
                OnboardingNavigationLabel(title: "Import from StoryGraph", symbol: "square.and.arrow.down", detail: "Choose and review a CSV before anything is saved")
            }.buttonStyle(.plain).simultaneousGesture(TapGesture().onEnded { chooseLibrary(.storyGraphImport) })
                .accessibilityIdentifier("onboarding.import")
            if state.libraryChoice == .storyGraphImport {
                StatusChip(importCompleted ? "Import saved" : "Import not finished", symbol: importCompleted ? "checkmark" : "clock")
                AppButton("Continue", action: continueAfterImport).disabled(!importCompleted)
                    .accessibilityIdentifier("onboarding.import.continue")
            }
            AppButton("Start Fresh", kind: .secondary, action: {
                chooseLibrary(.startFresh)
                advance(to: .libraryReady)
            }).accessibilityIdentifier("onboarding.fresh")
            back(to: .preferredEdition)
        }
    }

    private var libraryReady: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(DesignTokens.secondary(scheme)).accessibilityHidden(true)
            title("Your library is ready")
            Text(state.libraryChoice == .storyGraphImport ? "Your confirmed StoryGraph history is available. Any items needing review remain visible without blocking your library." : "Your library is ready for its first book. You can import a StoryGraph CSV later from your Reader Passport.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Journal Format is never guessed or preselected. You choose it for each reading when it is useful.")
                .foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal: false, vertical: true)
            AppButton("Open Reading Companion", symbol: "arrow.right", action: finish)
                .accessibilityIdentifier("onboarding.finish")
            back(to: .importOrStartFresh)
        }
    }

    private func title(_ value: String) -> some View {
        Text(value).font(DesignTokens.functionalFont(size: 30, relativeTo: .largeTitle, weight: .semiBold))
            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }

    private func back(to step: OnboardingStep) -> some View {
        AppButton("Back", kind: .tertiary, action: { advance(to: step) }).accessibilityIdentifier("onboarding.back")
    }

    private func saveYear() {
        guard let year = Int(yearText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            error = OnboardingError.invalidReadingHistoryYear.localizedDescription; return
        }
        var candidate = state
        candidate.readingHistorySince = year
        candidate.step = .preferredEdition
        save(candidate)
    }

    private func chooseLanguage(_ language: PreferredEditionLanguage) {
        var candidate = state
        candidate.preferredEditionLanguage = language
        save(candidate)
    }

    private func chooseLibrary(_ choice: OnboardingLibraryChoice) {
        var candidate = state
        candidate.libraryChoice = choice
        save(candidate)
    }

    private func continueAfterImport() {
        refreshImportStatus()
        guard importCompleted else { error = OnboardingError.importNotCompleted.localizedDescription; return }
        advance(to: .libraryReady)
    }

    private func advance(to step: OnboardingStep) {
        var candidate = state
        candidate.step = step
        save(candidate)
    }

    private func save(_ candidate: OnboardingState) {
        do {
            guard let repository = model.onboardingRepository else { throw OnboardingError.incompleteStep }
            try repository.saveOnboardingState(candidate)
            state = candidate
            error = nil
        }
        catch { self.error = error.localizedDescription }
    }

    private func refreshImportStatus() {
        importCompleted = (try? model.onboardingRepository?.hasCompletedStoryGraphImport()) ?? false
    }

    private func finish() {
        do {
            guard let completed = try model.onboardingRepository?.completeOnboarding(state) else { throw OnboardingError.incompleteStep }
            state = completed
            model.preferredEditionLanguage = completed.preferredEditionLanguage ?? .english
            onComplete(completed)
        } catch { self.error = error.localizedDescription }
    }
}

private struct OnboardingNavigationLabel: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let symbol: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).frame(width: 28, height: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(DesignTokens.functionalFont(size: 17, relativeTo: .headline, weight: .semiBold))
                Text(detail).font(DesignTokens.functionalFont(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").accessibilityHidden(true)
        }.padding(16).frame(minHeight: 64)
            .background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: 12))
    }
}
