import SwiftUI
import ReadingDomain

public struct ChallengesHome: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.colorScheme) private var scheme
    @State private var state: ChallengeYearState?
    @State private var years: [Int] = []
    @State private var year: Int
    public init(year: Int? = nil) { _year = State(initialValue: year ?? BooksModel.today.year) }
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let state {
                Text(String(year)).font(DesignTokens.functionalFont(size: 22, relativeTo: .title2, weight: .semiBold)).accessibilityIdentifier("challenges.year")
                Text("Version \(state.configuration.version.rawValue)").font(DesignTokens.functionalFont(size: 13, relativeTo: .caption)).foregroundStyle(DesignTokens.secondaryText(scheme)).accessibilityIdentifier("challenges.version")
                challengeLink("Review Matches", id: "challenges.review") { ChallengeReviewScreen(year: year) }
                challengeLink("Challenge Archive", id: "challenges.archive") { ChallengeArchive() }
                Text("My Challenges").font(DesignTokens.functionalFont(size: 20, relativeTo: .title2, weight: .semiBold))
                ForEach(ChallengeKind.allCases, id: \.self) { kind in
                    NavigationLink { ChallengeDetailScreen(year: year, kind: kind) } label: {
                        ChallengeOverviewRow(kind: kind, state: state)
                    }.buttonStyle(.plain).accessibilityIdentifier("challenges.kind." + kind.rawValue)
                }
            }
            BooksErrorMessage()
        }.font(DesignTokens.functionalFont(size: 16)).foregroundStyle(DesignTokens.text(scheme))
            .onAppear(perform: reload).onChange(of: model.version) { _,_ in reload() }
    }
    private func reload() {
        guard let repo = model.challengesRepository else { return }
        do { try repo.ensureChallengeYear(year: year); state = try repo.challengeYear(year: year); years = try repo.challengeYears() }
        catch { model.error = "Could not load Challenges. Saved records have not been deleted." }
    }
}

private struct ChallengeOverviewRow: View {
    @Environment(\.colorScheme) private var scheme
    let kind: ChallengeKind; let state: ChallengeYearState
    var body: some View {
        let prompts = state.configuration.prompts.filter { $0.challenge == kind }
        let completed = prompts.filter { state.assignment($0) != nil }.count
        VStack(alignment: .leading, spacing: 8) {
            Text(kind.name).font(DesignTokens.functionalFont(size: 17, relativeTo: .headline, weight: .semiBold)).fixedSize(horizontal: false, vertical: true)
            ChallengeProgress(completed: completed, total: prompts.count)
            if prompts.contains(where: { !$0.available }) {
                Label(kind == .roulette ? "Prompts not configured" : "Some prompts not configured", systemImage: "info.circle").font(DesignTokens.functionalFont(size: 13, relativeTo: .caption)).foregroundStyle(DesignTokens.secondaryText(scheme))
            }
        }.padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()).overlay(alignment: .bottom) { Divider() }
            .accessibilityElement(children: .combine)
    }
}

struct ChallengeDetailScreen: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.colorScheme) private var scheme
    let year: Int; let kind: ChallengeKind
    @State private var state: ChallengeYearState?
    var body: some View {
        BooksScreen(kind.name) {
            if let state {
                let prompts = state.configuration.prompts.filter { $0.challenge == kind }
                Text("\(year) · Version \(state.configuration.version.rawValue)").foregroundStyle(DesignTokens.secondaryText(scheme))
                ChallengeProgress(completed: prompts.filter { state.assignment($0) != nil }.count, total: prompts.count)
                if kind == .weeks { Text("Finish date determines the ISO week, Monday–Sunday. No borrowing between weeks. Same-day ties without a reliable finish order require your choice. Week 53 is not configured.").fixedSize(horizontal: false, vertical: true) }
                if kind == .hundred { Text("Numbered completion slots. DNF readings do not count.") }
                if kind == .alphabet { Text("Leading the, a, an, le, la and les are ignored. At most two books from the same series.") }
                if kind == .seasonal || kind == .monthly { Text("Eligibility follows the reading’s finish month.").foregroundStyle(DesignTokens.secondaryText(scheme)) }
                if kind == .world { Text("Cities only. A setting cannot be inferred from the author’s nationality or publisher.") }
                if kind == .roulette { StatePresentation(kind: .empty, title: "Prompts not configured", message: "The ten prompt slots are preserved. Missing content will not be guessed.") }
                if let proposal = state.proposals.first, prompts.contains(where: { $0.id == proposal.promptID }) {
                    ChallengeProposalPanel(proposal: proposal, state: state, reload: reload)
                }
                if !kind.semantic {
                    Text("Confirmed placements").font(DesignTokens.functionalFont(size: 20, relativeTo: .title2, weight: .semiBold))
                }
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(prompts) { prompt in
                        ChallengePromptRow(prompt: prompt, state: state, year: year, reload: reload)
                    }
                }
            }
            BooksErrorMessage()
        }.onAppear(perform: reload).onChange(of: model.version) { _,_ in reload() }
    }
    private func reload() { state = try? model.challengesRepository?.challengeYear(year: year) }
}

private struct ChallengeProgress: View {
    @Environment(\.colorScheme) private var scheme
    let completed: Int; let total: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(completed) of \(total) confirmed").font(DesignTokens.functionalFont(size: 13, relativeTo: .caption, weight: .medium)).foregroundStyle(DesignTokens.secondaryText(scheme))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DesignTokens.border(scheme))
                    Capsule().fill(Color(hex: 0x4F81AA)).frame(width: proxy.size.width * (total > 0 ? Double(completed) / Double(total) : 0))
                }
            }.frame(height: 7)
        }.accessibilityElement(children: .ignore).accessibilityLabel("Challenge progress").accessibilityValue("\(completed) of \(total) confirmed")
    }
}

private struct ChallengePromptRow: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var model: BooksModel
    @State private var removing = false
    let prompt: ChallengePrompt; let state: ChallengeYearState; let year: Int; let reload: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let group = prompt.group { Text(group).font(DesignTokens.functionalFont(size: 12, relativeTo: .caption, weight: .medium)).foregroundStyle(DesignTokens.secondaryText(scheme)) }
            Text(prompt.text ?? "Prompt \(prompt.order) · Not configured").font(DesignTokens.functionalFont(size: 16, relativeTo: .body, weight: .semiBold)).fixedSize(horizontal: false, vertical: true)
            if let assignment = state.assignment(prompt) {
                Label("Confirmed", systemImage: "checkmark.circle.fill").foregroundStyle(DesignTokens.primary(scheme))
                Text(state.bookTitle(readingID: assignment.readingID)).fixedSize(horizontal: false, vertical: true)
                Text(assignment.source == "manual" ? "Manual assignment" : assignment.confidence.map { "\($0)% MATCH · Confirmed by you" } ?? "From reading completion")
                    .font(DesignTokens.functionalFont(size: 13, relativeTo: .caption)).foregroundStyle(DesignTokens.secondaryText(scheme))
                AppButton("Correct assignment", kind: .tertiary) { removing = true }
                    .alert("Clear this assignment?", isPresented: $removing) {
                        Button("Clear assignment") { _ = model.perform { try model.challengesRepository?.removeChallengeAssignment(id: assignment.id, year: year, confirmed: true) }; reload() }
                        Button("Cancel", role: .cancel) {}
                    } message: { Text("The prompt will become free so you can choose another eligible book. Copied Journal changes remain reviewable.") }
                if prompt.challenge == .weeks {
                    challengeLink("Replace within this week", id: "challenges.replace." + prompt.key) { ChallengeManualAssignment(prompt: prompt, state: state, replacement: true, reload: reload) }
                }
                if let record = state.readings.first(where: { $0.id == assignment.readingID }) {
                    challengeLink("Prepare for my journal", id: "challenges.journal." + prompt.key) { ChallengeJournalPreparation(readingID: record.id, year: year) }
                }
            } else if prompt.available {
                Label(state.proposals.contains { $0.promptID == prompt.id } ? "Proposed · Not confirmed" : "Free", systemImage: state.proposals.contains { $0.promptID == prompt.id } ? "questionmark.circle" : "circle").foregroundStyle(DesignTokens.secondaryText(scheme))
                challengeLink("Assign a book", id: "challenges.assign." + prompt.key) { ChallengeManualAssignment(prompt: prompt, state: state, replacement: false, reload: reload) }
            } else { Label("Unavailable", systemImage: "info.circle").foregroundStyle(DesignTokens.secondaryText(scheme)) }
        }.padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading).overlay(alignment: .bottom) { Divider() }.accessibilityIdentifier("challenges.prompt." + prompt.key)
    }
}

struct ChallengeReviewScreen: View {
    @EnvironmentObject private var model: BooksModel
    let year: Int
    @State private var state: ChallengeYearState?
    var body: some View {
        BooksScreen("Review Matches") {
            if let state {
                Text(String(year))
                if let proposal = state.proposals.first {
                    AttentionRow(title: "Review a suggested match", detail: "A proposal does not occupy a prompt until you confirm.", category: "Challenges")
                    ChallengeProposalPanel(proposal: proposal, state: state, reload: reload)
                } else {
                    StatePresentation(kind: .empty, title: state.hasAnalysis ? "No more eligible matches" : "Not enough information", message: state.hasAnalysis ? "No remaining free prompt reaches 70% with the stored evidence. You can assign a book manually." : "Reliable book evidence is not available for semantic analysis. You can assign a book manually.")
                }
                Text("Semantic analysis is not connected yet. No book content has been guessed.")
                challengeLink("Choose a challenge", id: "challenges.choose") { ChallengesHome(year: year) }
            }
            BooksErrorMessage()
        }.onAppear(perform: reload).onChange(of: model.version) { _,_ in reload() }
    }
    private func reload() { state = try? model.challengesRepository?.challengeYear(year: year) }
}

private struct ChallengeProposalPanel: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.colorScheme) private var scheme
    let proposal: ChallengeProposal; let state: ChallengeYearState; let reload: () -> Void
    @State private var assistantUnavailable = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggested match", systemImage: "questionmark.circle").font(DesignTokens.functionalFont(size: 14, weight: .semiBold)).foregroundStyle(DesignTokens.secondary(scheme))
            Text(state.bookTitle(readingID: proposal.readingID)).font(DesignTokens.functionalFont(size: 19, relativeTo: .headline, weight: .semiBold)).fixedSize(horizontal: false, vertical: true)
            if let prompt = state.configuration.prompts.first(where: { $0.id == proposal.promptID }) {
                Text(prompt.challenge.name).foregroundStyle(DesignTokens.secondaryText(scheme))
                Text(prompt.text ?? "Not configured").fixedSize(horizontal: false, vertical: true)
            }
            Text(proposal.percentage).font(DesignTokens.functionalFont(size: 13, relativeTo: .caption, weight: .medium)).foregroundStyle(DesignTokens.secondary(scheme)).accessibilityIdentifier("challenges.confidence")
            Text("Match confidence, not a probability.").font(DesignTokens.functionalFont(size: 12, relativeTo: .caption)).foregroundStyle(DesignTokens.secondaryText(scheme))
            Text(proposal.evidence.explanation).fixedSize(horizontal: false, vertical: true)
            Text("Source: \(proposal.evidence.source) · \(proposal.evidence.reference)").font(DesignTokens.functionalFont(size: 13, relativeTo: .caption)).fixedSize(horizontal: false, vertical: true)
            AppButton("Confirm", symbol: "checkmark") { if model.perform({ try model.challengesRepository?.confirmChallengeProposal(id: proposal.id, year: state.configuration.year) }) != nil { reload() } }.accessibilityIdentifier("challenges.confirm")
            AppButton("Reject", kind: .secondary) { if model.perform({ try model.challengesRepository?.rejectChallengeProposal(id: proposal.id, year: state.configuration.year) }) != nil { reload() } }.accessibilityIdentifier("challenges.reject")
            AppButton("Ask Assistant", kind: .tertiary) {
                Task {
                    do { _ = try await UnavailableChallengeAssistant().explain(proposal: proposal, approvedContext: proposal.evidence.explanation) }
                    catch { assistantUnavailable = true }
                }
            }.accessibilityIdentifier("challenges.assistant")
            if assistantUnavailable { Text("Assistant unavailable. No analysis was requested and nothing was confirmed. You can use the evidence above or assign manually.").fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("challenges.assistant.unavailable") }
        }.padding(16).background(DesignTokens.plumSurface(scheme), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ChallengeManualAssignment: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.dismiss) private var dismiss
    let prompt: ChallengePrompt; let state: ChallengeYearState; let replacement: Bool; let reload: () -> Void
    @State private var selected: UUID?
    var body: some View {
        BooksScreen(replacement ? "Replace week assignment" : "Manual assignment") {
            Text(prompt.text ?? "Not configured").font(DesignTokens.functionalFont(size: 20, relativeTo: .title2, weight: .semiBold))
            Text(replacement ? "Only a book finished in this same ISO week can replace the current assignment. The displaced book will not move to another week." : "Your choice is authoritative. No AI confidence score is attached.")
            let records = state.readings.filter { ChallengeRules.eligible($0, prompt: prompt, year: state.configuration.year) }
            if records.isEmpty { StatePresentation(kind: .empty, title: "No eligible finished book", message: "A known finish date is needed for this year and period. DNF readings are excluded.") }
            ForEach(records) { record in
                Button { selected = record.id } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(record.book.title, systemImage: selected == record.id ? "checkmark.circle.fill" : "circle").fixedSize(horizontal: false, vertical: true)
                        Text(record.reading.finishDate?.isoString ?? "Finish date unknown")
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 8).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("challenges.select." + record.id.uuidString).accessibilityAddTraits(selected == record.id ? .isSelected : [])
            }
            AppButton(replacement ? "Confirm replacement" : "Confirm manual assignment", symbol: "checkmark") {
                guard let selected else { return }
                let result: Void? = model.perform {
                    if replacement { try model.challengesRepository?.replaceChallengeWeek(promptID: prompt.id, readingID: selected, year: state.configuration.year, confirmed: true) }
                    else { try model.challengesRepository?.assignChallenge(promptID: prompt.id, readingID: selected, year: state.configuration.year) }
                }
                if result != nil { reload(); dismiss() }
            }.disabled(selected == nil).accessibilityIdentifier("challenges.manual.confirm")
            BooksErrorMessage()
        }
    }
}

private struct ChallengeArchive: View {
    @EnvironmentObject private var model: BooksModel
    @State private var years: [Int] = []
    var body: some View {
        BooksScreen("Challenge Archive") {
            Text("Each year preserves its original prompts, version and confirmed assignments.")
            ForEach(years, id: \.self) { year in
                challengeLink("\(year) · Version \(ChallengeRules.version(year: year).rawValue)", id: "challenges.archived." + String(year)) { ChallengesHome(year: year) }
            }
        }.onAppear { years = (try? model.challengesRepository?.challengeYears()) ?? [] }
    }
}

private struct ChallengeJournalPreparation: View {
    @EnvironmentObject private var model: BooksModel
    let readingID: UUID; let year: Int
    @State private var state: ChallengeYearState?
    var body: some View {
        BooksScreen("Challenges for my journal") {
            if let state {
                Text(state.bookTitle(readingID: readingID)).font(DesignTokens.functionalFont(size: 22, relativeTo: .title2, weight: .semiBold))
                ForEach(state.assignments.filter { $0.readingID == readingID }) { assignment in
                    if let prompt = state.configuration.prompts.first(where: { $0.id == assignment.promptID }) { Text("\(prompt.challenge.name) · \(prompt.text ?? "Not configured")").fixedSize(horizontal: false, vertical: true) }
                }
                AppButton("Copied to my journal") { _ = model.perform { try model.challengesRepository?.markChallengesCopied(readingID: readingID) } }.accessibilityIdentifier("challenges.copied")
            }
            BooksErrorMessage()
        }.onAppear { state = try? model.challengesRepository?.challengeYear(year: year) }
    }
}

@ViewBuilder private func challengeLink<Destination: View>(_ text: String, id: String, @ViewBuilder destination: () -> Destination) -> some View {
    NavigationLink(destination: destination) {
        Label(text, systemImage: "chevron.right").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
    }.accessibilityIdentifier(id)
}
