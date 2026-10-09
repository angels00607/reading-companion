import SwiftUI
import ReadingDomain

public struct ProfileVisualQA: View {
    @EnvironmentObject private var model: BooksModel
    let route: String
    @State private var quests = [QuestInstance]()
    @State private var achievements = [AchievementProgress]()
    @State private var states = [String: CosmeticState]()
    @State private var level = 1
    @State private var loaded = false
    @State private var error: String?
    public init(route: String) { self.route = route }
    public var body: some View {
        NavigationStack {
            Group {
                if loaded {
                    switch route {
                    case "quests": QuestCenter(quests: quests)
                    case "achievements": AchievementsScreen(values: achievements)
                    case "collection": CollectionScreen(level: level, states: states)
                    case "reward": BooksScreen("Reward") {
                        if let reward = model.gamificationReward {
                            FeatureCelebration(eyebrow:model.gamificationRewardTitle,title:"Your reading milestone",message:reward,dismiss:{ model.gamificationReward = nil })
                        } else { Text("No new level has been reached.") }
                    }
                    default: ProfileHome()
                    }
                } else if let error {
                    StatePresentation(kind: .error, title: "Review fixture unavailable", message: error)
                } else { SkeletonRow() }
            }.task {
                do {
                    guard let repo = model.gamificationRepository else { throw GamificationError.invalidTarget }
                    quests = try repo.currentQuests()
                    achievements = try repo.achievementProgress()
                    states = try repo.cosmeticStates()
                    level = GamificationBalance.level(totalXP: try repo.xpAwards().reduce(0) { $0 + $1.amount })
                    // Construct state-owning destinations only after the fixture is available.
                    loaded = true
                } catch { self.error = "Could not load the existing review fixture." }
            }
            #if DEBUG
            .toolbar {
                if route == "quests" && ProcessInfo.processInfo.arguments.contains("-phase7-fixture") {
                    Button("Record acceptance activity") { recordAcceptanceActivity() }
                        .accessibilityIdentifier("phase7.recordActivity").frame(minHeight:44)
                }
            }
            #endif
        }
    }
    #if DEBUG
    private func recordAcceptanceActivity() {
        // Instrumented input uses real repository commands, never presentation-only state.
        _ = model.perform {
            let book = try model.repository.add(work:.init(provider:"manual",reference:UUID().uuidString,title:"An acceptance reading",author:"Reader"),edition:nil,choice:.addAnyway)
            let reading = try model.repository.start(bookID:book,editionID:nil,mode:.page,date:nil)
            _ = try model.repository.update(readingID:reading,value:.pages(current:10),revision:0,observationID:UUID())
        }
    }
    #endif
}

public struct HomePrimaryQuest: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.scenePhase) private var scene
    @State private var quest: QuestInstance?
    public init() {}
    public var body: some View {
        VStack(alignment:.leading,spacing:8) {
            Text("TODAY'S QUEST").font(DesignTokens.functionalFont(size:12,weight:.semiBold))
            if let quest { QuestCard(quest:quest) }
            else { Text("No current Quest is available. Your recorded reading is unchanged.") }
            NavigationLink("See all Quests") { QuestCenter(quests:[]) }.frame(minHeight:44)
        }.accessibilityIdentifier("phase7.homeQuest")
        .task(id:model.version) { load() }
        .onChange(of:scene) { _,phase in if phase == .active { load() } }
        .task { while !Task.isCancelled { try? await Task.sleep(for:.seconds(60)); if !Task.isCancelled { load() } } }
    }
    private func load() { do { let values = try model.gamificationRepository?.currentQuests() ?? []; quest = values.first { $0.cadence == .daily && !$0.isComplete } ?? values.first { $0.cadence == .daily } } catch { quest = nil } }
}

public struct ProfileHome:View {
    @EnvironmentObject private var model:BooksModel; @Environment(\.colorScheme) private var scheme; @Environment(\.dynamicTypeSize) private var typeSize
    @State private var passport=ReaderPassport(); @State private var awards=[XPAward](); @State private var achievements=[AchievementProgress](); @State private var quests=[QuestInstance](); @State private var cosmetics=[String:CosmeticState](); @State private var bookCount=0; @State private var pageCount="Unknown"; @State private var attentionCount=0; @State private var error:String?
    public init(){}
    private var xp:Int { awards.reduce(0){$0+$1.amount} }; private var level:Int { GamificationBalance.level(totalXP:xp) }
    public var body:some View { BooksScreen("Reader Passport") {
        passportHeader
        if let reward = model.gamificationReward {
            FeatureCelebration(eyebrow:model.gamificationRewardTitle,title:"Your reading milestone",message:reward,dismiss:{ model.gamificationReward = nil })
        }
        levelCard
        metrics
        favorites
        featured
        NavigationLink { NeedsAttentionScreen() } label: { AttentionRow(title:"Needs Attention",detail:attentionCount == 0 ? "No unresolved decisions" : "\(attentionCount) unresolved decision\(attentionCount == 1 ? "" : "s")",category:"All") }.buttonStyle(.plain).accessibilityIdentifier("attention.open")
        NavigationLink("Open Quest Center") { QuestCenter(quests:quests) }.buttonStyle(ProfileLinkStyle())
        NavigationLink("View all Achievements") { AchievementsScreen(values:achievements) }.buttonStyle(ProfileLinkStyle())
        NavigationLink("Open Collection") { CollectionScreen(level:level,states:cosmetics) }.buttonStyle(ProfileLinkStyle())
        NavigationLink("Data · StoryGraph Import") { ImportHome() }.buttonStyle(ProfileLinkStyle()).accessibilityIdentifier("import.open")
        NavigationLink("Sync & Backup") { BackupSettingsScreen() }.buttonStyle(ProfileLinkStyle()).accessibilityIdentifier("backup.open")
        NavigationLink("Notifications") { NotificationSettingsScreen() }.buttonStyle(ProfileLinkStyle()).accessibilityIdentifier("notifications.open")
        if let error { StatePresentation(kind:.error,title:"Profile unavailable",message:error) }
    }.task(id:model.version) { load() }.accessibilityIdentifier("phase7.profile") }
    private var passportHeader: some View {
        Group {
            if typeSize.isAccessibilitySize { VStack(alignment:.leading,spacing:16) { avatar; identity } }
            else { HStack(spacing:16) { avatar; identity } }
        }.padding(.vertical,8)
    }
    private var avatar: some View {
        ZStack {
            Circle().fill(cosmetics["background.midnight"] == .equipped ? DesignTokens.plumSurface(scheme) : DesignTokens.blueSurface(scheme)).frame(width:84,height:84)
            Image(systemName:passport.avatarSymbol).font(.system(size:48)).foregroundStyle(DesignTokens.primary(scheme))
            Circle().stroke(cosmetics["frame.classic"] == .equipped ? DesignTokens.secondary(scheme) : DesignTokens.border(scheme),lineWidth:3).frame(width:92,height:92)
        }.accessibilityLabel(cosmetics["frame.classic"] == .equipped ? "Reader avatar with equipped frame" : "Reader avatar")
    }
    private var identity: some View {
        VStack(alignment:.leading,spacing:5) {
            Text(passport.name).font(DesignTokens.functionalFont(size:26,relativeTo:.title,weight:.semiBold)).fixedSize(horizontal:false,vertical:true)
            Text("READING HISTORY SINCE \(String(passport.readingSince))").font(DesignTokens.functionalFont(size:12,relativeTo:.caption,weight:.medium)).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    private var levelIdentity: some View {
        VStack(alignment:.leading) {
            Text("LEVEL \(level)").font(DesignTokens.functionalFont(size:13,weight:.semiBold))
            Text("\(xp.formatted()) XP").font(DesignTokens.functionalFont(size:24,relativeTo:.title2,weight:.semiBold)).fixedSize(horizontal:false,vertical:true)
        }
    }
    private var remainingXP: some View {
        Text("\(GamificationBalance.xpPerLevel-GamificationBalance.progress(totalXP:xp)) XP to Level \(level+1)")
            .font(DesignTokens.functionalFont(size:13)).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
    }
    private var levelCard: some View {
        VStack(alignment:.leading,spacing:10) {
            if typeSize.isAccessibilitySize { VStack(alignment:.leading,spacing:10) { levelIdentity; remainingXP } }
            else { HStack { levelIdentity; Spacer(); remainingXP.multilineTextAlignment(.trailing) } }
            ReadingProgressBar(.percentage(Double(GamificationBalance.progress(totalXP:xp))/5.0))
        }.padding(16).background(DesignTokens.blueSurface(scheme),in:RoundedRectangle(cornerRadius:14)).accessibilityElement(children:.contain).accessibilityIdentifier("profile.level")
    }
    private var metrics:some View { ViewThatFits { HStack(spacing:8){metric("Books","\(bookCount)");metric("Pages",pageCount);metric("Achievements","\(achievements.filter(\.isUnlocked).count)")}; VStack(spacing:8){metric("Books","\(bookCount)");metric("Pages",pageCount);metric("Achievements","\(achievements.filter(\.isUnlocked).count)")} } }
    private func metric(_ label:String,_ value:String)->some View { VStack(spacing:3){Text(value).font(DesignTokens.functionalFont(size:20,weight:.semiBold));Text(label).font(DesignTokens.functionalFont(size:12)).foregroundStyle(DesignTokens.secondaryText(scheme))}.frame(maxWidth:.infinity,minHeight:64).background(DesignTokens.surface(scheme),in:RoundedRectangle(cornerRadius:12)) }
    private var favorites:some View { VStack(alignment:.leading,spacing:8){ Text("FAVORITES").font(DesignTokens.functionalFont(size:12,weight:.semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme)); Text("Favorite Books \u{00B7} \(passport.favoriteBooks.count) selected"); Text("Series \u{00B7} \(passport.favoriteSeries ?? "Not configured")\nAuthor \u{00B7} \(passport.favoriteAuthor ?? "Not configured")\nGenre \u{00B7} \(passport.favoriteGenre ?? "Not configured")").foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true) } }
    private var featured:some View { VStack(alignment:.leading,spacing:10){Text("FEATURED ACHIEVEMENTS").font(DesignTokens.functionalFont(size:12,weight:.semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme)); ForEach(achievements.filter{passport.featuredAchievementKeys.contains($0.definition.key)}) { AchievementBadgeView(value:$0) }; Text("Choose exactly 3 from Achievements").font(DesignTokens.functionalFont(size:13)).foregroundStyle(DesignTokens.secondaryText(scheme))} }
    private func load(){ do { guard let repo=model.gamificationRepository else{return}; passport=try repo.passport();awards=try repo.xpAwards();achievements=try repo.achievementProgress();quests=try repo.currentQuests();cosmetics=try repo.cosmeticStates();attentionCount=try model.attentionRepository?.unresolvedAttentionCount() ?? 0;if let stats=try model.statsRepository?.stats(period:.lifetime){bookCount=stats.books;pageCount=stats.pages.display} } catch { self.error="Existing local data has not changed." } }
}
struct ProfileLinkStyle:ButtonStyle { func makeBody(configuration:Configuration)->some View { configuration.label.font(DesignTokens.functionalFont(size:16,weight:.semiBold)).frame(maxWidth:.infinity,minHeight:48).background(.thinMaterial,in:RoundedRectangle(cornerRadius:12)).opacity(configuration.isPressed ? 0.7:1) } }

public struct QuestCenter: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scene
    @EnvironmentObject private var model: BooksModel
    @State private var quests: [QuestInstance]
    @State private var availability: [QuestCadence:Bool] = [:]
    @State private var error: String?
    init(quests:[QuestInstance]) { _quests = State(initialValue:quests) }
    public var body: some View {
        BooksScreen("Quest Center") {
            Text("Activity-based goals that adapt gently to genuine recent reading.").foregroundStyle(DesignTokens.secondaryText(scheme))
            ForEach(QuestCadence.allCases,id:\.self) { cadence in
                VStack(alignment:.leading,spacing:10) {
                    Text(cadence.rawValue.uppercased()).font(DesignTokens.functionalFont(size:13,weight:.semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme))
                    ForEach(quests.filter { $0.cadence == cadence }) { q in
                        QuestCard(quest:q).accessibilityIdentifier("quest."+q.id.uuidString)
                        if cadence != .monthly && !q.isComplete {
                            Button("Reroll this \(cadence.rawValue) Quest") { reroll(q.id) }
                                .disabled(availability[cadence] != true).frame(minHeight:44)
                                .accessibilityIdentifier("quest.reroll."+q.id.uuidString)
                        }
                    }
                    if cadence != .monthly { Text(availability[cadence] == true ? "1 free reroll available this period" : "Reroll unavailable · returns next period").font(DesignTokens.functionalFont(size:13)) }
                }
            }
            if let error { StatePresentation(kind:.error,title:"Quests unavailable",message:error) }
        }.accessibilityIdentifier("phase7.quests")
        .task(id:model.version) { load() }
        .onChange(of:scene) { _,phase in if phase == .active { load() } }
        .task { while !Task.isCancelled { try? await Task.sleep(for:.seconds(60)); if !Task.isCancelled { load() } } }
    }
    private func load() { do { guard let repo = model.gamificationRepository else { return }; quests = try repo.currentQuests(); for c in QuestCadence.allCases { availability[c] = try repo.rerollAvailable(c) }; error = nil } catch { self.error = "Could not load current Quests. Existing data is unchanged." } }
    private func reroll(_ id: UUID) { guard let repo = model.gamificationRepository else { return }; if model.perform({ try repo.rerollQuest(id) }) != nil { load() } }
}
private struct QuestCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    let quest: QuestInstance
    private var title: some View { Text(quest.title).font(DesignTokens.functionalFont(size:17,weight:.semiBold)).fixedSize(horizontal:false,vertical:true) }
    private var status: some View { StatusChip(quest.isComplete ? "Completed" : "+\(quest.cadence.xp) XP", symbol:quest.isComplete ? "checkmark":"sparkles", tone:quest.isComplete ? .special:.active) }
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            if typeSize.isAccessibilitySize { VStack(alignment:.leading,spacing:8) { title; status } }
            else { HStack { title; Spacer(); status } }
            Text("\(quest.progress) of \(quest.target) \(quest.unit)").foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
            ReadingProgressBar(.percentage(quest.target == 0 ? 0 : Double(quest.progress)*100/Double(quest.target)))
        }.frame(maxWidth:.infinity,alignment:.leading).padding(14)
            .background(DesignTokens.surface(scheme),in:RoundedRectangle(cornerRadius:14))
            .overlay { RoundedRectangle(cornerRadius:14).stroke(DesignTokens.border(scheme)) }
    }
}
public struct AchievementsScreen:View { @Environment(\.colorScheme) private var scheme; @EnvironmentObject private var model:BooksModel; @State private var values:[AchievementProgress]; @State private var selected=[String](); @State private var loadError:String?; init(values:[AchievementProgress]) { _values = State(initialValue:values) }; public var body:some View { BooksScreen("Achievements") { Text("All Achievements are visible. Select exactly 3 to feature on your Passport.").foregroundStyle(DesignTokens.secondaryText(scheme)); Text("\(selected.count) of 3 featured").font(DesignTokens.functionalFont(size:13,weight:.semiBold)); ForEach(values){ value in VStack(alignment:.leading,spacing:4){AchievementBadgeView(value:value);Button(selected.contains(value.definition.key) ? "Featured" : "Feature on Passport"){toggle(value.definition.key)}.disabled(!value.isUnlocked || (!selected.contains(value.definition.key) && selected.count==3)).frame(minHeight:44)} }; if let loadError { StatePresentation(kind:.error,title:"Achievement progress unknown",message:loadError) } }.task(id:model.version) { do { if let repo = model.gamificationRepository { _ = try repo.currentQuests(); values = try repo.achievementProgress(); selected = try repo.passport().featuredAchievementKeys; loadError = nil } } catch { values = AchievementCatalog.all.map { .init(definition:$0,progress:0,progressKnown:false) }; loadError = "Could not establish progress from local data." } }.accessibilityIdentifier("phase7.achievements") }
    private func toggle(_ key:String){if let i=selected.firstIndex(of:key){selected.remove(at:i)}else if selected.count<3{selected.append(key)};guard selected.count==3,let repo=model.gamificationRepository,var passport=try? repo.passport() else{return};passport.featuredAchievementKeys=selected;try? repo.savePassport(passport)}
}
private struct AchievementBadgeView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    let value: AchievementProgress
    private var icon: some View { ZStack { Circle().fill(value.isUnlocked ? DesignTokens.plumSurface(scheme):DesignTokens.blueSurface(scheme)).frame(width:54,height:54); Image(systemName:value.definition.symbol).font(.system(size:23)) } }
    @ViewBuilder private var check: some View { if value.isUnlocked { Image(systemName:"checkmark.circle.fill").accessibilityLabel("Unlocked") } }
    private var details: some View {
        VStack(alignment:.leading,spacing:4) {
            Text(value.definition.name).font(DesignTokens.functionalFont(size:16,weight:.semiBold)).fixedSize(horizontal:false,vertical:true)
            Text(value.isUnlocked ? "Unlocked":value.definition.condition).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
            if !value.isUnlocked {
                Text(value.progressKnown ? "\(min(value.progress,value.definition.target)) of \(value.definition.target)" : "Progress unknown").font(DesignTokens.functionalFont(size:12))
                if value.progressKnown { ReadingProgressBar(.percentage(Double(value.progress)*100/Double(value.definition.target))) }
            }
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { VStack(alignment:.leading,spacing:12) { HStack { icon; Spacer(); check }; details } }
            else { HStack(spacing:14) { icon; details; Spacer(); check } }
        }.frame(maxWidth:.infinity,alignment:.leading).padding(12)
            .background(DesignTokens.surface(scheme),in:RoundedRectangle(cornerRadius:14))
            .accessibilityElement(children:.contain)
    }
}
public struct CollectionScreen: View {
    @EnvironmentObject private var model: BooksModel
    @Environment(\.colorScheme) private var scheme
    @State private var level: Int
    @State private var states: [String:CosmeticState]
    @State private var preview: CosmeticDefinition?
    @State private var error: String?
    init(level:Int,states:[String:CosmeticState]) { _level = State(initialValue:level); _states = State(initialValue:states) }
    public var body: some View {
        BooksScreen("Collection") {
            Text("Cosmetics personalize surfaces and your Passport without changing semantic colors, typography or navigation.").foregroundStyle(DesignTokens.secondaryText(scheme))
            PassportCustomization(states:states)
            ForEach(CosmeticCategory.allCases,id:\.self) { category in
                Text(category.rawValue.uppercased()).font(DesignTokens.functionalFont(size:12,weight:.semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme))
                ForEach(CosmeticCatalog.all.filter { $0.category == category }) { item in
                    let state = states[item.key] ?? .locked
                    CosmeticRow(item:item,state:state)
                    Button(item.category == .themes ? "Preview Theme" : "Preview \(item.name)") { preview = item }
                        .disabled(state == .locked).frame(minHeight:44).accessibilityIdentifier("cosmetic.preview."+item.key)
                    if state == .equipped {
                        Button("Use default \(item.category.rawValue)") { useDefault(item) }.frame(minHeight:44)
                            .accessibilityIdentifier("cosmetic.default."+item.key)
                    }
                }
            }
            if let error { StatePresentation(kind:.error,title:"Collection unavailable",message:error) }
        }.task(id:model.version) { load() }.accessibilityIdentifier("phase7.collection")
        .sheet(item:$preview) { item in NavigationStack {
            BooksScreen(item.category == .themes ? "Theme Preview" : "Cosmetic Preview") {
                Text(item.name).font(DesignTokens.functionalFont(size:22,relativeTo:.title2,weight:.semiBold))
                PassportCustomization(states:previewStates(item))
                Text("Preview only. Apply saves this choice; Cancel keeps your previous appearance.")
                AppButton("Apply") { apply(item) }.accessibilityIdentifier("cosmetic.apply")
                AppButton("Cancel",kind:.secondary) { preview = nil }.accessibilityIdentifier("cosmetic.cancel")
                BooksErrorMessage()
            }.accessibilityIdentifier("phase7.preview")
        } }
    }
    private func previewStates(_ item:CosmeticDefinition) -> [String:CosmeticState] {
        var result = states; result[item.key] = .equipped
        if item.category == .themes { result["background.midnight"] = .equipped; result["frame.classic"] = .equipped }
        return result
    }
    private func apply(_ item:CosmeticDefinition) { guard let repo = model.gamificationRepository else { return }; if model.perform({ try repo.setCosmetic(item.key,state:.equipped) }) != nil { preview = nil; load() } }
    private func useDefault(_ item:CosmeticDefinition) { guard let repo = model.gamificationRepository else { return }; if model.perform({ try repo.setCosmetic(item.key,state:.unlocked) }) != nil { load() } }
    private func load() { do { guard let repo = model.gamificationRepository else { return }; states = try repo.cosmeticStates(); level = GamificationBalance.level(totalXP:try repo.xpAwards().reduce(0) { $0+$1.amount }); error = nil } catch { self.error = "Could not load Collection. Existing equipment is unchanged." } }
}

/// Decorative customization is deliberately local to Passport surfaces. Functional tokens never change.
private struct PassportCustomization: View {
    @Environment(\.colorScheme) private var scheme
    let states: [String:CosmeticState]
    private func equipped(_ key:String) -> Bool { states[key] == .equipped }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Image(systemName:"person.crop.circle.fill").font(.system(size:48))
                    .padding(8).overlay { Circle().stroke(equipped("frame.classic") ? DesignTokens.secondary(scheme) : DesignTokens.border(scheme),lineWidth:3) }
                    .accessibilityLabel("Reader avatar preview")
                if equipped("decoration.sparkle") { Image(systemName:"sparkles").accessibilityHidden(true) }
            }
            Text("Reader Passport").font(DesignTokens.functionalFont(size:20,weight:.semiBold))
            Text(equipped("theme.modern-bookish") ? "Modern Bookish · applied surfaces" : "Your current decorative surfaces").font(DesignTokens.functionalFont(size:13))
            Image(systemName:"bookmark.fill").foregroundStyle(equipped("accent.berry") ? DesignTokens.secondary(scheme) : DesignTokens.primary(scheme)).accessibilityHidden(true)
        }.frame(maxWidth:.infinity,alignment:.leading).padding(16)
            .background(equipped("background.midnight") ? DesignTokens.plumSurface(scheme) : DesignTokens.blueSurface(scheme),in:RoundedRectangle(cornerRadius:14))
            .overlay { RoundedRectangle(cornerRadius:14).stroke(equipped("card.frosted") ? DesignTokens.primary(scheme) : DesignTokens.border(scheme)) }
            .foregroundStyle(DesignTokens.text(scheme)).accessibilityIdentifier("cosmetic.passportSurface")
    }
}

private struct CosmeticRow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    let item: CosmeticDefinition
    let state: CosmeticState
    private var icon: some View { Image(systemName:item.category == .frames ? "circle.dashed":"paintpalette") }
    private var marker: some View { Image(systemName:state == .equipped ? "checkmark.circle.fill":state == .locked ? "lock.fill":"circle") }
    private var details: some View {
        VStack(alignment:.leading) {
            Text(item.name).font(DesignTokens.functionalFont(size:16,weight:.semiBold)).fixedSize(horizontal:false,vertical:true)
            Text(state == .locked ? "Unlocks at Level \(item.unlockLevel)":state.rawValue.capitalized).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { VStack(alignment:.leading,spacing:8) { HStack { icon; Spacer(); marker }; details }.padding(.vertical,12) }
            else { HStack { icon; details; Spacer(); marker } }
        }.frame(maxWidth:.infinity,minHeight:58,alignment:.leading).padding(.horizontal,12)
            .background(DesignTokens.surface(scheme),in:RoundedRectangle(cornerRadius:12))
            .accessibilityElement(children:.combine)
            .accessibilityIdentifier("cosmetic.row."+item.key)
            .accessibilityValue(state.rawValue)
    }
}
