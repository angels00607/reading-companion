import XCTest
import ReadingDomain
@testable import ReadingData

final class Phase10AOnboardingTests: XCTestCase {
    private func store(path: String = ":memory:", owner: UUID = UUID()) throws -> LocalStore {
        try LocalStore(path: path, ownerID: owner)
    }

    func testFirstOpeningStartsAtWelcomeAndResumePersists() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let owner = UUID()
        let first = try store(path: url.path, owner: owner)
        XCTAssertEqual(try first.onboardingState(), OnboardingState())

        let saved = OnboardingState(step: .preferredEdition, readingHistorySince: 2018)
        try first.saveOnboardingState(saved)
        let reopened = try store(path: url.path, owner: owner)
        XCTAssertEqual(try reopened.onboardingState(), saved)
    }

    func testStartFreshCompletesAndDoesNotReappearOrChangeHistoricalData() throws {
        let value = try store()
        let book = try value.add(work: .init(provider: "manual", reference: "existing", title: "Existing book", author: "Reader"))
        let reading = try value.start(bookID: book, editionID: nil, date: nil)
        _ = try value.update(readingID: reading, value: .pages(current: 12), revision: 0)
        let beforeBooks = try value.bookCount()
        let beforeAwards = try value.xpAwards()

        let draft = OnboardingState(step: .libraryReady, readingHistorySince: 2016,
            preferredEditionLanguage: .french, libraryChoice: .startFresh)
        let completed = try value.completeOnboarding(draft)

        XCTAssertTrue(completed.isComplete)
        XCTAssertEqual(try value.onboardingState(), completed)
        XCTAssertEqual(try value.passport().readingSince, 2016)
        XCTAssertEqual(try value.bookCount(), beforeBooks)
        let afterAwards = try value.xpAwards()
        XCTAssertEqual(afterAwards.map(\.semanticKey), beforeAwards.map(\.semanticKey))
        XCTAssertEqual(afterAwards.map(\.amount), beforeAwards.map(\.amount))
        XCTAssertEqual(try value.record(id: book).active?.progress.currentPage, 12)
    }

    func testCompletionPreservesExistingPassportPreferences() throws {
        let value = try store()
        let favorite = UUID()
        try value.savePassport(.init(name: "Taylor", avatarSymbol: "person.fill", readingSince: 2020,
            favoriteBooks: [favorite], favoriteSeries: "The Archive", favoriteAuthor: "A. Reader", favoriteGenre: "Fantasy"))
        _ = try value.completeOnboarding(.init(step: .libraryReady, readingHistorySince: 2012,
            preferredEditionLanguage: .english, libraryChoice: .startFresh))
        let passport = try value.passport()
        XCTAssertEqual(passport.name, "Taylor")
        XCTAssertEqual(passport.avatarSymbol, "person.fill")
        XCTAssertEqual(passport.favoriteBooks, [favorite])
        XCTAssertEqual(passport.favoriteSeries, "The Archive")
        XCTAssertEqual(passport.favoriteAuthor, "A. Reader")
        XCTAssertEqual(passport.favoriteGenre, "Fantasy")
        XCTAssertEqual(passport.readingSince, 2012)
    }

    func testStoryGraphChoiceRequiresExistingImportAndImportHasNoLiveSideEffects() throws {
        let value = try store()
        let draft = OnboardingState(step: .libraryReady, readingHistorySince: 2021,
            preferredEditionLanguage: .english, libraryChoice: .storyGraphImport)
        XCTAssertThrowsError(try value.completeOnboarding(draft)) { error in
            XCTAssertEqual(error as? OnboardingError, .importNotCompleted)
        }

        let csv = Data("Title,Authors,ISBN/UID,Read Status,Read Count,Dates Read,Last Date Read,Star Rating,Format\nImported History,Archive Author,onboarding-1,read,1,,2024/02/03,4,ebook\n".utf8)
        let preview = try value.previewStoryGraph(csv)
        _ = try value.applyImport(preview, confirmed: true)
        XCTAssertTrue(try value.hasCompletedStoryGraphImport())
        let awards = try value.xpAwards()
        let quests = try value.quests()
        let completed = try value.completeOnboarding(draft)
        XCTAssertTrue(completed.isComplete)
        XCTAssertTrue(awards.isEmpty)
        XCTAssertTrue(quests.isEmpty)
        XCTAssertTrue(try value.xpAwards().isEmpty)
    }

    func testMigrationPreservesUnknownReadingHistoryForExistingOwner() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let owner = UUID()
        let value = try store(path: url.path, owner: owner)
        _ = try value.add(work: .init(provider: "manual", reference: "legacy", title: "Existing", author: "Reader"))
        // A legacy owner with a library but no confirmed start year must not receive 2020.
        // Reopening the migrated store must keep the user's unknown year unknown.
        let reopened = try store(path: url.path, owner: owner)
        let state = try reopened.onboardingState()
        XCTAssertNil(state.readingHistorySince)
    }

    func testInvalidOrIncompleteValuesAreRejected() throws {
        let value = try store()
        XCTAssertThrowsError(try value.saveOnboardingState(.init(step: .readingHistorySince, readingHistorySince: 999)))
        XCTAssertThrowsError(try value.completeOnboarding(.init(step: .libraryReady, readingHistorySince: 2020)))
    }
}
