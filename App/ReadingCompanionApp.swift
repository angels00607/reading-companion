import SwiftUI
import ReadingUI
import ReadingData
import ReadingDomain

@main
struct ReadingCompanionApp: App {
    @State private var model: BooksModel?
    @State private var storageError: String?
    var body: some Scene {
        WindowGroup {
            Group {
                if isFoundationQA { FoundationShell() }
                else if let model {
                    if let route = visualQARoute { BooksVisualQA(route: route).environmentObject(model) }
                    else if let route = challengeQARoute { ChallengesVisualQA(route: route).environmentObject(model) }
                    else if let route = statsQARoute { StatsVisualQA(route: route).environmentObject(model) }
                    else if let route = profileQARoute { ProfileVisualQA(route:route).environmentObject(model) }
                    else { FoundationShell(homeContent: AnyView(VStack(alignment:.leading,spacing:20){BooksHome();HomePrimaryQuest()}), journalContent: AnyView(JournalHome()), seriesContent: AnyView(SeriesHome()), challengesContent: AnyView(ChallengesHome(year: challengeQAYear)), statsContent:AnyView(StatsHome()), profileContent:AnyView(ProfileHome())).environmentObject(model) }
                }
                else if let storageError { StatePresentation(kind: .error, title: "Library unavailable", message: storageError) }
                else { SkeletonRow() }
            }.preferredColorScheme(acceptanceAppearance)
                .onAppear {
                    if !isFoundationQA && model == nil { openStore() }
                    #if DEBUG
                    Phase0Diagnostics.shared.start()
                    #endif
                }
        }
    }
    private var challengeQAYear: Int? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-phase5-fixture") { return 2027 }
        #endif
        return nil
    }
    private var statsQARoute:String? {
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        if let index=args.firstIndex(of:"-phase6-screen"),index+1<args.count { return args[index+1] }
        #endif
        return nil
    }
    private var profileQARoute:String? {
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        if let index=args.firstIndex(of:"-phase7-screen"),index+1<args.count{return args[index+1]}
        #endif
        return nil
    }
    private var challengeQARoute: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-phase5-screen"), index + 1 < args.count { return args[index + 1] }
        #endif
        return nil
    }
    #if DEBUG
    private func seedChallengesQA(_ store: LocalStore) throws {
        for year in [2026,2027,2028] { try store.ensureChallengeYear(year: year) }
        func completed(_ reference: String, _ title: String, _ date: ReadingDate) throws -> UUID {
            let book = try store.add(work: WorkCandidate(provider: "qa-challenges", reference: reference, title: title, author: "Fictional QA Author"))
            let reading = try store.start(bookID: book, editionID: nil, date: nil)
            try store.finish(readingID: reading, confirmed: true, date: date, revision: 0)
            return reading
        }
        let reading = try completed("winter", "The Deliberately Long Story of Two Childhood Friends Reunited at a Winter Sports Festival in New York City", try ReadingDate(year: 2027, month: 12, day: 8))
        _ = try completed("manual", "The Amber Garden", try ReadingDate(year: 2027, month: 3, day: 1))
        _ = try completed("week-second", "The Blue Notebook", try ReadingDate(year: 2027, month: 3, day: 3))
        _ = try completed("different-week", "Another Week", try ReadingDate(year: 2027, month: 3, day: 10))
        let config = try store.challengeYear(year: 2027).configuration
        let candidates: [(ChallengeKind,String,Int,String)] = [
            (.tropes,"prompt.10",99,"Fictional fixture synopsis explicitly states a childhood-friends romance."),
            (.world,"easy.1",88,"Fictional fixture synopsis explicitly identifies New York City as the setting."),
            (.monthly,"12.1",70,"Fictional fixture synopsis explicitly describes a winter sport; the reading finished in December.")
        ]
        let proposals = candidates.map { kind,key,score,explanation in
            ChallengeProposal(readingID: reading, promptID: config.prompts.first { $0.challenge == kind && $0.key == key }!.id, confidence: score,
                evidence: ChallengeEvidence(fingerprint: "fictional-fixture-\(kind.rawValue)-v1", source: "Fictional visual QA evidence", reference: "Fixture synopsis â€” not a provider analysis", explanation: explanation, reliable: true))
        }
        try store.storeChallengeProposals(proposals, year: 2027)
    }
    #endif
    private var isFoundationQA: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-phase0-diagnostics")
        #else
        return false
        #endif
    }
    private var visualQARoute: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-phase2-screen"), index + 1 < args.count { return args[index + 1] }
        #endif
        return nil
    }
    @MainActor private func openStore() {
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("ReadingCompanion", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            // Local-only owner identity until approved auth/onboarding integration. Never sent as an auth credential.
            let identity = root.appendingPathComponent("local-owner.txt")
            let owner: UUID
            if FileManager.default.fileExists(atPath: identity.path) {
                guard let value = UUID(uuidString: try String(contentsOf: identity, encoding: .utf8)) else { throw BooksError.invalidMetadata }
                owner = value
            } else { owner = UUID(); try owner.uuidString.write(to: identity, atomically: true, encoding: .utf8) }
            #if DEBUG
            let qa = ProcessInfo.processInfo.arguments.contains("-phase2-fixture") || ProcessInfo.processInfo.arguments.contains("-phase3-fixture") || ProcessInfo.processInfo.arguments.contains("-phase4-fixture") || ProcessInfo.processInfo.arguments.contains("-phase5-fixture") || ProcessInfo.processInfo.arguments.contains("-phase6-fixture") || ProcessInfo.processInfo.arguments.contains("-phase7-fixture")
            #else
            let qa = false
            #endif
            let store = try LocalStore(path: qa ? ":memory:" : root.appendingPathComponent(owner.uuidString + ".sqlite").path, ownerID: owner)
            if ProcessInfo.processInfo.arguments.contains("-phase3-fixture") { try seedJournalQA(store) }
            if ProcessInfo.processInfo.arguments.contains("-phase4-fixture") { try seedSeriesQA(store) }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-phase5-fixture") { try seedChallengesQA(store) }
            if ProcessInfo.processInfo.arguments.contains("-phase6-fixture") { try seedStatsQA(store) }
            if ProcessInfo.processInfo.arguments.contains("-phase7-fixture") { try seedGamificationQA(store) }
            #endif
            model = BooksModel(repository: store, journalRepository: store, seriesRepository: store, challengesRepository: store, provider: qa ? BooksAcceptanceProvider() : OpenLibraryProvider(), assetDirectory: root.appendingPathComponent(owner.uuidString + "-covers"))
        } catch { storageError = "Could not open the local database. Existing files have not been reset or deleted." }
    }
    #if DEBUG
    private func seedGamificationQA(_ store:LocalStore) throws {
        for n in 1...12 { _ = try store.awardXP(try XPAward(semanticKey:"qa:\(n)",source:n <= 8 ? .finishBook:.journalWork,amount:n <= 8 ? 100:40)) }; _ = try store.awardXP(try XPAward(semanticKey:"quest:qa-complete",source:.dailyQuest,amount:GamificationBalance.amount(for:.dailyQuest)))
        let daily=QuestRules.candidates(cadence:.daily,periodKey:"2026-10-06",activity:.init(genuinePagesPerDay:[18,24,22],sessionsPerWeek:[3,4,4]),history:[])
        let weekly=QuestRules.candidates(cadence:.weekly,periodKey:"2026-W41",activity:.init(sessionsPerWeek:[3,4,4],journalActionsPerWeek:[2,3]),history:daily)
        let monthly=QuestRules.candidates(cadence:.monthly,periodKey:"2026-10",activity:.init(completionsPerMonth:[1,2,2],journalActionsPerWeek:[2,3]),history:daily+weekly)
        var quests=daily+weekly+monthly; quests[0].progress=max(1,quests[0].target-1); quests[1].progress=quests[1].target; quests[1].completedAt=Date(); quests[2].rerolledAt=Date(); try store.saveQuests(quests)
        var achievements=try store.achievementProgress(); achievements[0]=.init(definition:achievements[0].definition,progress:1,unlockedAt:Date()); achievements[1]=.init(definition:achievements[1].definition,progress:7); achievements[2]=.init(definition:achievements[2].definition,progress:5,unlockedAt:Date()); achievements[4]=.init(definition:achievements[4].definition,progress:3); try store.saveAchievementProgress(achievements)
        let featured=[achievements[0].definition.key,achievements[2].definition.key,achievements[3].definition.key]; try store.savePassport(.init(name:"Sarah Reader",readingSince:2020,featuredAchievementKeys:featured))
        try store.setCosmetic("frame.classic",state:.equipped); try store.setCosmetic("theme.modern-bookish",state:.equipped); try store.setCosmetic("background.midnight",state:.unlocked)
    }
    private func seedStatsQA(_ store:LocalStore) throws {
        func completed(_ title:String,_ month:Int,_ day:Int,_ rating:Rating,_ format:JournalFormat?,_ pages:Int?,year:Int=2026,bookID:UUID?=nil) throws -> (UUID,UUID) {
            let book:UUID
            if let bookID { book=bookID } else { book=try store.add(work:.init(provider:"qa-stats",reference:UUID().uuidString,title:title,author:"Fictional QA Author"),choice:.addAnyway) }
            let rid=try store.start(bookID:book,editionID:nil,mode:pages==nil ? .percentage : .page,date:nil)
            _ = try store.update(readingID:rid,value:pages.map { try! ReadingProgress.pages(current:$0) } ?? .percentage(100),revision:0)
            let finish=try ReadingDate(year:year,month:month,day:day)
            try store.finish(readingID:rid,confirmed:true,date:finish,revision:1)
            try store.editReading(readingID:rid,start:nil,finish:finish,rating:rating,genre:pages==nil ? nil : "Historical Fantasy and the Extremely Long Name of a Reader\u{2019}s Chosen Primary Genre",format:format,revision:2)
            return (book,rid)
        }
        let first=try completed("The Very Long Chronicle of the Moonlit Bookshop and the Readers Who Returned to It",9,5,.stars(5),.paperback,100)
        let second=try completed("A Map of Quiet Places",9,21,.stars(3),.hardcover,120)
        _ = try completed("An Unrated Percentage-Only Reading",9,25,.noRating,nil,nil)
        _ = try completed("The Very Long Chronicle of the Moonlit Bookshop and the Readers Who Returned to It",2,1,.stars(4),.ebook,80,year:2027,bookID:first.0)
        let unknown=try store.add(work:.init(provider:"qa-stats",reference:"unknown",title:"A Historical Reading Without Daily Activity",author:"Fictional QA Author"))
        let historical=try store.recordCompleted(bookID:unknown,editionID:nil,date:try ReadingDate(year:2025,month:12,day:5),rating:.noRating)
        try store.prepareStatsHistoricalPercentageQA(readingID:historical)
        let undated=try store.add(work:.init(provider:"qa-stats",reference:"undated",title:"A Completed Reading With Unknown Finish Date",author:"Fictional QA Author"))
        _ = try store.recordCompleted(bookID:undated,editionID:nil,date:nil,rating:.unknown)
        let dnfBook=try store.add(work:.init(provider:"qa-stats",reference:"dnf",title:"DNF Is Excluded",author:"Fictional QA Author"))
        let dnf=try store.start(bookID:dnfBook,editionID:nil,date:nil)
        _ = try store.update(readingID:dnf,value:.pages(current:250),revision:0)
        try store.markDNF(readingID:dnf,revision:1)
        try store.recordReadingActivity(readingID:first.1,date:ReadingDate(year:2026,month:9,day:4),sourceReference:"Explicit fictional QA reading-day record")
        try store.recordReadingActivity(readingID:second.1,date:ReadingDate(year:2026,month:9,day:4),sourceReference:"Explicit fictional QA reading-day record")
        try store.recordReadingActivity(readingID:second.1,date:ReadingDate(year:2026,month:9,day:20),sourceReference:"Explicit fictional QA reading-day record")
        if ProcessInfo.processInfo.arguments.contains("-phase6-selected") {
            try store.selectBestBook(period:.month(year:2026,month:9),readingID:first.1,expectedRevision:0)
        }
        if ProcessInfo.processInfo.arguments.contains("-phase6-year-selected") {
            try store.selectBestBook(period:.year(2026),readingID:first.1,expectedRevision:0)
        }
    }
    #endif
    private func seedSeriesQA(_ store: LocalStore) throws {
        let fixtures: [(String, SeriesStatus?, SeriesStatusEvidence, Bool)] = [
            ("The Extremely Long Chronicle of the Moonlit Archive and Its Keepers", nil, .init(hasUnreadIncludedPublished: true), false),
            ("Waiting for the Final Volume", nil, .init(allIncludedPublishedRead: true, hasAnnouncedOrExpectedFutureEntry: true), false),
            ("A Completed Trilogy", nil, .init(allIncludedConfirmedRead: true, confirmedComplete: true), true),
            ("The Uncertain Cycle", nil, .init(allIncludedPublishedRead: true), false),
            ("A Series Left Behind", .abandoned, .init(hasUnreadIncludedPublished: true), false)
        ]
        for (index, fixture) in fixtures.enumerated() {
            // Fixed QA timestamps keep the reviewed first row deterministic across launches.
            let id = UUID(); let series = ReadingSeries(id: id, ownerID: store.ownerID, name: fixture.0, author: "Taylor Reader", userStatusOverride: fixture.1, evidence: fixture.2, finalTotalKnown: fixture.3, updatedAt: Date(timeIntervalSince1970: 1_700_000_000 - Double(index) * 86_400))
            let count = index == 0 ? 25 : 3
            var entries = [SeriesEntry]()
            for number in 1...count {
                let fractional = number == 2 ? Decimal(string: "1.5")! : Decimal(number)
                let future = index == 1 && number == count
                let title = number == 2 ? "A Very Long Related Book Title That Must Wrap Without Losing Its Meaning" : "Volume \(number)"
                let bookID: UUID?
                if future { bookID = nil }
                else {
                    let book = try store.add(work: WorkCandidate(provider: "qa-series", reference: "\(index)-\(number)", title: title, author: "Taylor Reader"), choice: .addAnyway)
                    bookID = book
                    if index == 2 || index == 1 || (index == 0 && number == 1) {
                        let reading = try store.start(bookID: book, editionID: nil, date: nil)
                        try store.finish(readingID: reading, confirmed: true, date: nil, revision: 0)
                    }
                }
                entries.append(SeriesEntry(seriesID: id, bookID: bookID, title: title, position: fractional, kind: number == 2 ? .related : .main, publication: future ? .announced : .published, release: future ? .year(2028) : .unknown, isRead: index == 1 || index == 2 || (index == 0 && number == 1)))
            }
            try store.saveSeries(series, entries: entries)
            if index == 0 { try store.propose(seriesID: id, field: "Position", current: "1.5", proposed: "2.5", source: "Catalogue update", evidenceFingerprint: "qa-position-v1") }
        }
    }
    private func seedJournalQA(_ store: LocalStore) throws {
        let first = try store.add(work: WorkCandidate(provider: "qa", reference: "journal-1", title: "The Very Long Title of a Book Remembered in a Handwritten Journal", author: "Alexandra Example"))
        let reading = try store.start(bookID: first, editionID: nil, date: try ReadingDate(year: 2026, month: 9, day: 4))
        try store.finish(readingID: reading, confirmed: true, date: try ReadingDate(year: 2026, month: 9, day: 28), revision: 0)
        try store.saveBookReview(readingID: reading, draft: BookReviewDraft(summary: "A thoughtful summary written by the reader, ready to copy into the physical journal.", pageCount: 384, rating: .stars(5), format: .hardcover, start: try ReadingDate(year: 2026, month: 9, day: 4), finish: try ReadingDate(year: 2026, month: 9, day: 28)))
        try store.setFavorite(bookID: first, decision: .selected)
        try store.saveQuote(JournalQuote(bookID: first, readingID: reading, text: "A representative quote for visual review.", source: "p. 184", includeInJournal: true))
        try store.markBookReviewCopied(readingID: reading)
        try store.saveBookReview(readingID: reading, draft: BookReviewDraft(summary: "A corrected summary that now differs from the version copied on paper.", pageCount: 384, rating: .stars(5), format: .hardcover, start: try ReadingDate(year: 2026, month: 9, day: 4), finish: try ReadingDate(year: 2026, month: 9, day: 28)))
        let second = try store.add(work: WorkCandidate(provider: "qa", reference: "journal-2", title: "A Pending Review", author: "Morgan Reader"))
        let secondReading = try store.start(bookID: second, editionID: nil, date: nil)
        try store.finish(readingID: secondReading, confirmed: true, date: nil, revision: 0)
        let third = try store.add(work: WorkCandidate(provider: "qa", reference: "journal-3", title: "Ready for the Next Journal Session", author: "Jamie Writer"))
        let thirdReading = try store.start(bookID: third, editionID: nil, date: nil)
        try store.finish(readingID: thirdReading, confirmed: true, date: nil, revision: 0)
        try store.saveBookReview(readingID: thirdReading, draft: BookReviewDraft(summary: "Ready to be copied during a focused session.", pageCount: nil, rating: .noRating, format: .ebook, start: nil, finish: nil))
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
