import XCTest
@testable import ReadingDomain

final class Phase5ChallengesTests: XCTestCase {
    func testRotationAndCompleteConfiguredTypes() throws {
        for (year,version) in [(2026,ChallengeVersion.a),(2027,.b),(2028,.a)] {
            let config = try ChallengeCatalog.configuration(year: year)
            XCTAssertEqual(config.version, version)
            XCTAssertEqual(Set(config.prompts.map(\.challenge)), Set(ChallengeKind.allCases))
            XCTAssertEqual(config.prompts.filter { $0.challenge == .tropes }.count, 20)
        }
    }
    func testCatalogHolesKeepTheirIdentityAndAreUnavailable() throws {
        let config = try ChallengeCatalog.configuration(year: 2027)
        XCTAssertNil(config.prompts.first { $0.challenge == .archetype && $0.key == "prompt.10" }?.text)
        XCTAssertEqual(config.prompts.first { $0.challenge == .archetype && $0.key == "prompt.11" }?.text, "The Immortal")
        XCTAssertEqual(config.prompts.filter { $0.challenge == .archetype }.count, 21)
        XCTAssertEqual(config.prompts.first { $0.challenge == .monthly && $0.key == "12.1" }?.text, "Winter Sport")
        XCTAssertNil(config.prompts.first { $0.challenge == .monthly && $0.key == "12.2" }?.text)
        XCTAssertNil(config.prompts.first { $0.challenge == .monthly && $0.key == "12.3" }?.text)
        let roulette = config.prompts.filter { $0.challenge == .roulette }
        XCTAssertEqual(roulette.count, 10); XCTAssertTrue(roulette.allSatisfy { !$0.available })
    }
    private func record(date: ReadingDate?, historical: Bool = false, status: ReadingStatus = .read, title: String = "The Amber Garden") throws -> ChallengeReading {
        let book = Book(ownerID: UUID(), title: title, author: "Author")
        var reading = ReadingInstance(bookID: book.id, status: status, progress: try .pages(current: nil, total: nil), historical: historical)
        reading.finishDate = date
        return ChallengeReading(book: book, reading: reading)
    }
    func testSeasonalAndMonthlyFinishMonthBoundaries() throws {
        let config = try ChallengeCatalog.configuration(year: 2027)
        for month in 1...12 {
            let value = try record(date: ReadingDate(year: 2027, month: month, day: 1))
            let seasonal = config.prompts.filter { $0.challenge == .seasonal && ChallengeRules.eligible(value, prompt: $0, year: 2027) }
            XCTAssertEqual(seasonal.count, 5)
            XCTAssertTrue(seasonal.allSatisfy { $0.months!.contains(month) })
            let monthly = config.prompts.filter { $0.challenge == .monthly && ChallengeRules.eligible(value, prompt: $0, year: 2027) }
            XCTAssertEqual(monthly.count, month == 12 ? 1 : 3)
            XCTAssertTrue(monthly.allSatisfy { $0.month == month })
        }
    }
    func testThresholdReliabilityBestAndRejectionIdentity() throws {
        let config = try ChallengeCatalog.configuration(year: 2027)
        let record = try record(date: ReadingDate(year: 2027, month: 2, day: 2))
        let prompts = config.prompts.filter { $0.challenge == .tropes }
        func proposal(_ index: Int, _ score: Int, _ reliable: Bool = true, _ fingerprint: String = "v1") -> ChallengeProposal {
            ChallengeProposal(readingID: record.id, promptID: prompts[index].id, confidence: score, evidence: .init(fingerprint: fingerprint, source: "Verified source", reference: "Chapter reference", explanation: "Supplied evidence", reliable: reliable))
        }
        let a = proposal(0,91), b = proposal(1,84), c = proposal(2,70)
        let values = [a,b,c,proposal(3,69),proposal(4,99,false)]
        func best(_ rejected: Set<String>, occupied: Set<UUID> = []) -> ChallengeProposal? {
            ChallengeRules.best(values, prompts: config.prompts, readings: [record], occupied: occupied, rejected: rejected, year: 2027)
        }
        XCTAssertEqual(best([])?.confidence, 91)
        let ka = ChallengeRules.rejectionKey(bookID: record.book.id, promptID: a.promptID, evidence: a.evidence)
        let kb = ChallengeRules.rejectionKey(bookID: record.book.id, promptID: b.promptID, evidence: b.evidence)
        let kc = ChallengeRules.rejectionKey(bookID: record.book.id, promptID: c.promptID, evidence: c.evidence)
        XCTAssertEqual(best([ka])?.confidence, 84)
        XCTAssertEqual(best([ka,kb])?.percentage, "70% MATCH")
        XCTAssertNil(best([ka,kb,kc]))
        XCTAssertEqual(best([], occupied: [a.promptID])?.id, b.id)
        XCTAssertNotEqual(ka, ChallengeRules.rejectionKey(bookID: record.book.id, promptID: a.promptID, evidence: proposal(0,82,true,"v2").evidence))
    }
    func testAlphabetArticlesAndPossessives() {
        for title in ["The Amber Garden","A Amber Garden","An Amber Garden","Le Amber Garden","La Amber Garden","Les Amber Garden"] { XCTAssertEqual(ChallengeRules.alphabetLetter(title), "A") }
        XCTAssertEqual(ChallengeRules.alphabetLetter("My Garden"), "M")
        XCTAssertEqual(ChallengeRules.alphabetLetter("Her Story"), "H")
        XCTAssertNil(ChallengeRules.alphabetLetter("123 Days"))
    }
    func testDNFUnknownFinishAndHistoricalDoNotAutoAnalyze() throws {
        let config = try ChallengeCatalog.configuration(year: 2027); let prompt = config.prompts.first { $0.challenge == .tropes }!
        XCTAssertFalse(ChallengeRules.eligible(try record(date: nil), prompt: prompt, year: 2027, automatic: true))
        XCTAssertFalse(ChallengeRules.eligible(try record(date: ReadingDate(year: 2027, month: 1, day: 1), status: .dnf), prompt: prompt, year: 2027))
        let imported = try record(date: ReadingDate(year: 2027, month: 1, day: 1), historical: true)
        XCTAssertFalse(ChallengeRules.eligible(imported, prompt: prompt, year: 2027, automatic: true))
        XCTAssertTrue(ChallengeRules.eligible(imported, prompt: prompt, year: 2027))
    }
    func testISOYearBoundaryMondaySundayAndFirstChronological() throws {
        let sunday = try ReadingDate(year: 2027, month: 1, day: 3)
        let monday = try ReadingDate(year: 2027, month: 1, day: 4)
        XCTAssertEqual(sunday.isoWeek, ISOWeek(year: 2026, week: 53))
        XCTAssertEqual(monday.isoWeek, ISOWeek(year: 2027, week: 1))
        let first = try record(date: ReadingDate(year: 2027, month: 3, day: 1))
        let later = try record(date: ReadingDate(year: 2027, month: 3, day: 3))
        XCTAssertEqual(ChallengeRules.firstFinished(in: first.reading.finishDate!.isoWeek, readings: [later,first])?.id, first.id)
        let tie = try record(date: first.reading.finishDate)
        XCTAssertNil(ChallengeRules.firstFinished(in: first.reading.finishDate!.isoWeek, readings: [first,tie,later]))
        XCTAssertEqual(try ChallengeCatalog.configuration(year: 2026).prompts.filter { $0.challenge == .weeks }.count, 52)
    }
    func testWeeksAndHundredNeverUseSemanticMatching() throws {
        let config = try ChallengeCatalog.configuration(year: 2027)
        XCTAssertFalse(ChallengeKind.weeks.semantic); XCTAssertFalse(ChallengeKind.hundred.semantic)
        XCTAssertEqual(config.prompts.filter { $0.challenge == .hundred }.count, 100)
        XCTAssertEqual(config.prompts.filter { $0.challenge == .alphabet }.count, 26)
    }
    func testSnapshotSerializationDoesNotReconstructCurrentCatalog() throws {
        let config = try ChallengeCatalog.configuration(year: 2026)
        let saved = try JSONEncoder().encode(config)
        let later = ChallengeConfiguration(year: 2026, catalogRevision: "later-evolution", prompts: [])
        XCTAssertNotEqual(config, later)
        XCTAssertEqual(try JSONDecoder().decode(ChallengeConfiguration.self, from: saved), config)
    }
}
