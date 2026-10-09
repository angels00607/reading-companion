import Foundation

public enum NotificationCategory: String, CaseIterable, Codable, Sendable {
    case seriesReleases = "series_releases"
    case releaseDateChanges = "release_date_changes"
    case importAndSystem = "import_system"
    case challenges, journal, quests
    case achievementsAndLevels = "achievements_levels"

    public var label: String {
        switch self {
        case .seriesReleases: "Series & New Releases"
        case .releaseDateChanges: "Release Date Changes"
        case .importAndSystem: "Import & System"
        case .challenges: "Challenges"
        case .journal: "Journal"
        case .quests: "Quests"
        case .achievementsAndLevels: "Achievements & Levels"
        }
    }
}

public struct NotificationPreferences: Equatable, Sendable {
    public var seriesReleases: Bool
    public var releaseDateChanges: Bool
    public var importAndSystem: Bool
    public var challenges: Bool
    public var journal: Bool
    public var quests: Bool
    /// Nil is intentional: the specification does not define a default.
    public var achievementsAndLevels: Bool?
    public init(seriesReleases:Bool=true,releaseDateChanges:Bool=true,importAndSystem:Bool=true,challenges:Bool=false,journal:Bool=false,quests:Bool=false,achievementsAndLevels:Bool?=nil) {
        self.seriesReleases=seriesReleases;self.releaseDateChanges=releaseDateChanges;self.importAndSystem=importAndSystem;self.challenges=challenges;self.journal=journal;self.quests=quests;self.achievementsAndLevels=achievementsAndLevels
    }
    public func enabled(_ category:NotificationCategory) -> Bool {
        switch category { case .seriesReleases:seriesReleases;case .releaseDateChanges:releaseDateChanges;case .importAndSystem:importAndSystem;case .challenges:challenges;case .journal:journal;case .quests:quests;case .achievementsAndLevels:achievementsAndLevels == true }
    }
}

public enum NotificationAuthorizationState:String,Sendable { case authorized, denied, notDetermined, provisional, unavailable }
public enum NotificationDestination:Equatable,Sendable { case series(UUID), needsAttention }
public struct VerifiedNotificationEvent:Equatable,Sendable {
    public let id:String;public let category:NotificationCategory;public let date:ReadingDate;public let destination:NotificationDestination
    public let title:String;public let body:String
    public init(id:String,category:NotificationCategory,date:ReadingDate,destination:NotificationDestination,title:String,body:String){self.id=id;self.category=category;self.date=date;self.destination=destination;self.title=title;self.body=body}
}

public protocol NotificationPreferencesRepository:Sendable {
    func notificationPreferences() throws -> NotificationPreferences
    func setNotificationPreference(_ category:NotificationCategory,enabled:Bool) throws
    func verifiedNotificationEvents(after:ReadingDate) throws -> [VerifiedNotificationEvent]
}

public protocol NotificationDeliveryService:Sendable {
    func authorizationStatus() async -> NotificationAuthorizationState
    func requestAuthorization() async -> NotificationAuthorizationState
    /// Atomically reconciles this app-owned category using stable request identifiers.
    func replacePending(category:NotificationCategory,events:[VerifiedNotificationEvent]) async throws
}
