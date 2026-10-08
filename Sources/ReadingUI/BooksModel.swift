import Foundation
import SwiftUI
import ReadingDomain

@MainActor
public final class BooksModel: ObservableObject {
    public let repository: any BooksRepository
    public let provider: any BooksCatalogProvider
    public let journalRepository: (any JournalRepository)?
    public let challengesRepository: (any ChallengesRepository)?
    public let seriesRepository: (any SeriesRepository)?
    public let statsRepository: (any StatsRepository)?
    public let gamificationRepository: (any GamificationRepository)?
    public let backupService: (any BackupService)?
    public let assetDirectory: URL
    @Published public var version = 0
    @Published public var error: String?
    @Published public var feedback: String?
    @Published public var feedbackReadingID: UUID?
    @Published public var gamificationReward: String?
    @Published public var gamificationRewardTitle = "LEVEL UP"
    public init(repository: any BooksRepository, journalRepository: (any JournalRepository)? = nil, seriesRepository: (any SeriesRepository)? = nil, challengesRepository: (any ChallengesRepository)? = nil, statsRepository:(any StatsRepository)? = nil, gamificationRepository:(any GamificationRepository)? = nil, provider: any BooksCatalogProvider, assetDirectory: URL, backupService:(any BackupService)? = nil) {
        self.repository = repository; self.journalRepository = journalRepository; self.seriesRepository = seriesRepository; self.challengesRepository = challengesRepository
        self.statsRepository = statsRepository ?? (repository as? any StatsRepository)
        self.gamificationRepository = gamificationRepository ?? (repository as? any GamificationRepository)
        self.provider = provider; self.assetDirectory = assetDirectory;self.backupService=backupService
    }
    @discardableResult public func perform<T>(_ body: () throws -> T) -> T? {
        do {
            let prior = try? gamificationRepository?.xpAwards()
            let value = try body()
            if let before = prior, let after = try? gamificationRepository?.xpAwards() {
                let oldLevel = GamificationBalance.level(totalXP:before.reduce(0) { $0+$1.amount }), newLevel = GamificationBalance.level(totalXP:after.reduce(0) { $0+$1.amount })
                let previous = Set(before.map(\.semanticKey)), added = after.filter { !previous.contains($0.semanticKey) }
                if newLevel > oldLevel {
                    gamificationRewardTitle = "LEVEL UP"
                    gamificationReward = "Level \(newLevel). Your configured cosmetics are available. Every reading feature remains available."
                } else if let achievement = added.first(where: { $0.source == .achievement }) {
                    gamificationRewardTitle = "ACHIEVEMENT UNLOCKED"
                    let key = String(achievement.semanticKey.dropFirst("achievement:".count))
                    gamificationReward = "\(AchievementCatalog.all.first { $0.key == key }?.name ?? "Achievement"). +\(achievement.amount) XP awarded once."
                } else if let quest = added.first(where: { [.dailyQuest,.weeklyQuest,.monthlyQuest].contains($0.source) }) {
                    gamificationRewardTitle = "QUEST COMPLETED"
                    gamificationReward = "+\(quest.amount) XP awarded once. Your reading progress has been saved."
                }
            }
            error = nil; version += 1; return value
        }
        catch DomainError.staleRevision { error = "The record changed. Reload and review before applying this change." }
        catch DomainError.invalidProgress { error = "Enter a valid position: pages must be whole numbers within the known total; percentage must be between 0 and 100." }
        catch BooksError.activeReadingExists { error = "This book already has an active reading. Open it to update progress." }
        catch BooksError.requiredMetadata { error = "Enter a title and author. Optional metadata may stay unknown." }
        catch BooksError.invalidMetadata { error = "Check the supplied information. Cover references must be a chosen photo or a valid HTTPS URL." }
        catch DomainError.invalidDate { error = "Use a valid date in YYYY-MM-DD format, or leave it blank for unknown." }
        catch { self.error = "Could not save this change. Existing local data has not changed. \(error.localizedDescription)" }
        return nil
    }
    public func coverURL(_ reference: String?) -> URL? {
        guard let reference else { return nil }
        if reference.hasPrefix("asset://"), let id = UUID(uuidString: String(reference.dropFirst(8)).replacingOccurrences(of: ".png", with: "")) {
            return assetDirectory.appendingPathComponent(id.uuidString + ".png")
        }
        guard let url = URL(string: reference), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
    public func saveCover(_ data: Data) throws -> String {
        guard data.count <= 10_000_000 else { throw BooksError.invalidMetadata }
        try FileManager.default.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
        let id = UUID(); try data.write(to: assetDirectory.appendingPathComponent(id.uuidString + ".png"), options: .atomic)
        return "asset://" + id.uuidString + ".png"
    }
    public static var today: ReadingDate {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year,.month,.day], from: Date())
        return try! ReadingDate(year: parts.year!, month: parts.month!, day: parts.day!)
    }
    public static func parseDate(_ value: String) throws -> ReadingDate? {
        if value.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        return try JSONDecoder().decode(ReadingDate.self, from: JSONEncoder().encode(value))
    }
    public static func optionalPages(_ value: String) throws -> Int? {
        if value.isEmpty { return nil }
        guard let pages = Int(value), pages > 0 else { throw DomainError.invalidProgress }; return pages
    }
}

struct BooksScreen<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .frame(maxWidth: .infinity, alignment: .leading).padding(DesignTokens.margin).padding(.bottom, 24)
        }.background(DesignTokens.background(scheme)).foregroundStyle(DesignTokens.text(scheme))
            .font(DesignTokens.functionalFont(size: 16)).navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            #endif
    }
}
struct BooksField: View {
    @Environment(\.colorScheme) private var scheme
    let label: String
    @Binding var value: String
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(DesignTokens.functionalFont(size: 14, weight: .medium))
            TextField(text: $value, axis: .vertical) {
                Text(label).foregroundStyle(DesignTokens.secondaryText(scheme))
            }.textFieldStyle(.roundedBorder)
                .font(DesignTokens.functionalFont(size: 16)).frame(minHeight: 44)
                .focused($focused)
                .accessibilityLabel(label).accessibilityIdentifier("books.field." + label)
                #if os(iOS)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        if focused {
                            Spacer()
                            Button("Done") { focused = false }
                                .font(DesignTokens.functionalFont(size: 16))
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityIdentifier("books.keyboardDone")
                        }
                    }
                }
                #endif
        }
    }
}
struct BooksErrorMessage: View {
    @EnvironmentObject var model: BooksModel
    var body: some View { if let error = model.error { StatePresentation(kind: .error, title: "Change not saved", message: error) } }
}
