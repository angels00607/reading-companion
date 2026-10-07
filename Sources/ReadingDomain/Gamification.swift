import Foundation

public enum XPSource: String, Codable, CaseIterable, Sendable { case finishBook, journalWork, challengeConfirmation, dailyQuest, weeklyQuest, monthlyQuest, achievement }
public enum GamificationBalance {
    public static let awards: [XPSource:Int] = [.finishBook:100,.journalWork:40,.challengeConfirmation:30,.dailyQuest:20,.weeklyQuest:60,.monthlyQuest:150]
    public static let xpPerLevel = 500
    public static let achievementRange = 50...250
    public static func amount(for source: XPSource) -> Int { awards[source] ?? 0 }
    public static func level(totalXP: Int) -> Int { max(1, totalXP / xpPerLevel + 1) }
    public static func progress(totalXP: Int) -> Int { max(0, totalXP) % xpPerLevel }
}

public enum GamificationError: Error { case invalidAward, duplicateAward, invalidTarget, rerollUnavailable, invalidFeaturedSelection, lockedCosmetic }

public enum QuestCadence: String, Codable, CaseIterable, Sendable { case daily, weekly, monthly
    public var activeCount:Int { switch self { case .daily:2; case .weekly,.monthly:3 } }
    public var xp:Int { GamificationBalance.amount(for: xpSource) }
    public var xpSource:XPSource { switch self { case .daily:.dailyQuest; case .weekly:.weeklyQuest; case .monthly:.monthlyQuest } }
}
public enum QuestFamily: String, Codable, CaseIterable, Sendable { case frequency, pages, sessions, progress, completion, journalActivity, organization, consistency }
public struct ActivitySummary: Equatable, Sendable {
    public let genuinePagesPerDay: [Int]; public let sessionsPerWeek: [Int]; public let completionsPerMonth: [Int]; public let journalActionsPerWeek: [Int]; public let readingDaysPerWeek: [Int]
    public init(genuinePagesPerDay:[Int]=[],sessionsPerWeek:[Int]=[],completionsPerMonth:[Int]=[],journalActionsPerWeek:[Int]=[],readingDaysPerWeek:[Int]=[]) { self.genuinePagesPerDay=genuinePagesPerDay; self.sessionsPerWeek=sessionsPerWeek; self.completionsPerMonth=completionsPerMonth; self.journalActionsPerWeek=journalActionsPerWeek; self.readingDaysPerWeek=readingDaysPerWeek }
}
public struct QuestTemplate: Identifiable, Codable, Equatable, Sendable {
    public var id:String { key }; public let key:String; public let family:QuestFamily; public let cadences:Set<QuestCadence>; public let title:String; public let unit:String; public let minimum:Int; public let maximum:Int; public let cooldownPeriods:Int
}
public struct QuestInstance: Identifiable, Codable, Equatable, Sendable {
    public let id:UUID; public let templateKey:String; public let cadence:QuestCadence; public let periodKey:String; public let title:String; public let unit:String; public let target:Int; public var progress:Int; public var completedAt:Date?; public var rerolledAt:Date?
    public var isComplete:Bool { completedAt != nil || progress >= target }
    public init(id:UUID=UUID(),templateKey:String,cadence:QuestCadence,periodKey:String,title:String,unit:String,target:Int,progress:Int=0,completedAt:Date?=nil,rerolledAt:Date?=nil) { self.id=id; self.templateKey=templateKey; self.cadence=cadence; self.periodKey=periodKey; self.title=title; self.unit=unit; self.target=target; self.progress=max(0,min(progress,target)); self.completedAt=completedAt; self.rerolledAt=rerolledAt }
}
public enum QuestCatalog {
    public static let templates:[QuestTemplate] = [
        // Fixed, conservative action goals are available even before there is reading history.
        // Different templates rotate across quiet periods; no activity is fabricated.
        .init(key:"progress.record",family:.progress,cadences:[.daily,.weekly,.monthly],title:"Capture a reading update",unit:"updates",minimum:1,maximum:1,cooldownPeriods:1),
        .init(key:"organization.choose",family:.organization,cadences:[.daily,.weekly,.monthly],title:"Make a library choice",unit:"organized items",minimum:1,maximum:1,cooldownPeriods:1),
        .init(key:"progress.return",family:.progress,cadences:[.daily,.weekly,.monthly],title:"Check in with your reading",unit:"updates",minimum:2,maximum:2,cooldownPeriods:1),
        .init(key:"organization.care",family:.organization,cadences:[.daily,.weekly,.monthly],title:"Care for your bookshelf",unit:"organized items",minimum:2,maximum:2,cooldownPeriods:1),
        .init(key:"progress.note",family:.progress,cadences:[.daily,.weekly,.monthly],title:"Note your reading position",unit:"updates",minimum:1,maximum:1,cooldownPeriods:1),
        .init(key:"organization.tend",family:.organization,cadences:[.daily,.weekly,.monthly],title:"Tend a library item",unit:"organized items",minimum:1,maximum:1,cooldownPeriods:1),
        .init(key:"progress.check",family:.progress,cadences:[.daily,.weekly,.monthly],title:"Keep your progress current",unit:"updates",minimum:1,maximum:1,cooldownPeriods:1),
        .init(key:"organization.arrange",family:.organization,cadences:[.daily,.weekly,.monthly],title:"Arrange your reading shelf",unit:"organized items",minimum:1,maximum:1,cooldownPeriods:1),
        .init(key:"frequency.reading-days",family:.frequency,cadences:[.daily,.weekly,.monthly],title:"Make time to read",unit:"reading days",minimum:1,maximum:12,cooldownPeriods:1),
        .init(key:"pages.genuine",family:.pages,cadences:[.daily,.weekly,.monthly],title:"Turn a few pages",unit:"recorded pages",minimum:10,maximum:600,cooldownPeriods:1),
        .init(key:"sessions.recorded",family:.sessions,cadences:[.daily,.weekly,.monthly],title:"Return to your reading",unit:"sessions",minimum:1,maximum:18,cooldownPeriods:1),
        .init(key:"progress.updates",family:.progress,cadences:[.daily,.weekly],title:"Record your progress",unit:"updates",minimum:1,maximum:5,cooldownPeriods:1),
        .init(key:"completion.confirmed",family:.completion,cadences:[.weekly,.monthly],title:"Finish a reading journey",unit:"confirmed books",minimum:1,maximum:3,cooldownPeriods:2),
        .init(key:"journal.activity",family:.journalActivity,cadences:[.weekly,.monthly],title:"Spend time with your journal",unit:"journal actions",minimum:1,maximum:8,cooldownPeriods:1),
        .init(key:"organization.review",family:.organization,cadences:[.weekly,.monthly],title:"Tend your reading library",unit:"organized items",minimum:1,maximum:8,cooldownPeriods:2),
        .init(key:"consistency.sessions",family:.consistency,cadences:[.weekly,.monthly],title:"Keep a gentle reading rhythm",unit:"active days",minimum:2,maximum:12,cooldownPeriods:2)
    ]
}
public enum QuestRules {
    public static func target(for template:QuestTemplate,cadence:QuestCadence,activity:ActivitySummary) -> Int {
        let values:[Int]
        switch template.family { case .pages: values=activity.genuinePagesPerDay; case .sessions: values=activity.sessionsPerWeek; case .frequency,.consistency: values=activity.readingDaysPerWeek; case .completion: values=activity.completionsPerMonth; case .journalActivity: values=activity.journalActionsPerWeek; default: values=[] }
        let recent=Array(values.suffix(6)).sorted(); let smoothed = recent.isEmpty ? template.minimum : recent[recent.count/2]
        let scale: Int
        switch template.family {
        case .frequency,.consistency,.journalActivity: scale = cadence == .monthly ? 2 : 1
        case .completion: scale = 1
        default: scale = cadence == .daily ? 1 : cadence == .weekly ? 2 : 4
        }
        let cap = (template.family == .frequency || template.family == .consistency) ? (cadence == .daily ? 1 : cadence == .weekly ? 7 : 12) : template.maximum
        return min(cap,min(template.maximum,max(template.minimum,min(template.maximum,max(0,smoothed))*scale)))
    }
    public static func candidates(cadence:QuestCadence,periodKey:String,activity:ActivitySummary,history:[QuestInstance],excluding:Set<String>=[]) -> [QuestInstance] {
        let pool=QuestCatalog.templates.filter { template in
            template.cadences.contains(cadence) && !excluding.contains(template.key) &&
            QuestPeriod.cooldownAllows(template, cadence:cadence, periodKey:periodKey, history:history)
        }
        return pool.prefix(cadence.activeCount).map { .init(templateKey:$0.key,cadence:cadence,periodKey:periodKey,title:$0.title,unit:$0.unit,target:target(for:$0,cadence:cadence,activity:activity)) }
    }
}

public struct AchievementDefinition: Identifiable, Codable, Equatable, Sendable { public var id:String{key}; public let key:String; public let name:String; public let condition:String; public let target:Int; public let xp:Int; public let symbol:String }
public enum AchievementCatalog { public static let all:[AchievementDefinition] = [
    .init(key:"books.first",name:"First Chapter",condition:"Finish 1 book",target:1,xp:50,symbol:"book.closed.fill"),
    .init(key:"books.ten",name:"A Growing Shelf",condition:"Finish 10 books",target:10,xp:100,symbol:"books.vertical.fill"),
    .init(key:"journal.five",name:"In the Margins",condition:"Complete 5 Journal works",target:5,xp:100,symbol:"pencil.and.scribble"),
    .init(key:"quests.ten",name:"Gentle Momentum",condition:"Complete 10 Quests",target:10,xp:150,symbol:"sparkles"),
    .init(key:"level.five",name:"Reader at Heart",condition:"Reach Level 5",target:5,xp:0,symbol:"bookmark.fill")
] }
public struct AchievementProgress: Identifiable, Codable, Equatable, Sendable {
    public var id:String { definition.key }
    public let definition:AchievementDefinition
    public let progress:Int
    public let progressKnown:Bool
    public let unlockedAt:Date?
    public var isUnlocked:Bool { unlockedAt != nil }
    public init(definition:AchievementDefinition,progress:Int,unlockedAt:Date?=nil,progressKnown:Bool=true) {
        self.definition=definition;self.progress=max(0,progress);self.unlockedAt=unlockedAt;self.progressKnown=progressKnown
    }
    private enum CodingKeys:String,CodingKey { case definition,progress,unlockedAt,progressKnown }
    public init(from decoder:Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        self.init(definition:try c.decode(AchievementDefinition.self,forKey:.definition),progress:try c.decode(Int.self,forKey:.progress),unlockedAt:try c.decodeIfPresent(Date.self,forKey:.unlockedAt),progressKnown:try c.decodeIfPresent(Bool.self,forKey:.progressKnown) ?? true)
    }
}

public enum CosmeticCategory:String,Codable,CaseIterable,Sendable { case backgrounds, accents, frames, cards, decorations, themes }
public enum CosmeticState:String,Codable,Sendable { case locked, unlocked, equipped }
public struct CosmeticDefinition:Identifiable,Codable,Equatable,Sendable { public var id:String{key}; public let key:String; public let name:String; public let category:CosmeticCategory; public let unlockLevel:Int }
public enum CosmeticCatalog { public static let all:[CosmeticDefinition] = [
    .init(key:"background.midnight",name:"Midnight Reading",category:.backgrounds,unlockLevel:1), .init(key:"accent.berry",name:"Berry Bookmark",category:.accents,unlockLevel:2), .init(key:"frame.classic",name:"Classic Line",category:.frames,unlockLevel:1), .init(key:"card.frosted",name:"Frosted Page",category:.cards,unlockLevel:3), .init(key:"decoration.sparkle",name:"Quiet Sparkle",category:.decorations,unlockLevel:4), .init(key:"theme.modern-bookish",name:"Modern Bookish",category:.themes,unlockLevel:1)
] }

public struct ReaderPassport:Codable,Equatable,Sendable { public var name:String; public var avatarSymbol:String; public var readingSince:Int; public var favoriteBooks:[UUID]; public var favoriteSeries:String?; public var favoriteAuthor:String?; public var favoriteGenre:String?; public var featuredAchievementKeys:[String]
    public init(name:String="Reader",avatarSymbol:String="person.crop.circle.fill",readingSince:Int=2020,favoriteBooks:[UUID]=[],favoriteSeries:String?=nil,favoriteAuthor:String?=nil,favoriteGenre:String?=nil,featuredAchievementKeys:[String]=[]) { self.name=name; self.avatarSymbol=avatarSymbol; self.readingSince=readingSince; self.favoriteBooks=favoriteBooks; self.favoriteSeries=favoriteSeries; self.favoriteAuthor=favoriteAuthor; self.favoriteGenre=favoriteGenre; self.featuredAchievementKeys=featuredAchievementKeys }
}
public protocol GamificationRepository:Sendable {
    func passport() throws -> ReaderPassport; func savePassport(_ value:ReaderPassport) throws
    func xpAwards() throws -> [XPAward]; func awardXP(_ award:XPAward) throws -> Bool
    func currentQuests() throws -> [QuestInstance]
    func rerollQuest(_ id: UUID) throws
    func rerollAvailable(_ cadence: QuestCadence) throws -> Bool
    func quests() throws -> [QuestInstance]; func saveQuests(_ values:[QuestInstance]) throws
    func achievementProgress() throws -> [AchievementProgress]; func saveAchievementProgress(_ values:[AchievementProgress]) throws
    func cosmeticStates() throws -> [String:CosmeticState]; func setCosmetic(_ key:String,state:CosmeticState) throws
}
