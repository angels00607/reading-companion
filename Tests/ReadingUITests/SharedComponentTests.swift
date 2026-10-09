import XCTest
@testable import ReadingUI
import ReadingDomain

final class SharedComponentTests: XCTestCase {
    func testProgressPreservesPageAndPercentageMeaning() {
        XCTAssertEqual(ReadingProgressValue.pages(current: 187, total: 450).fraction, 187.0 / 450.0)
        XCTAssertEqual(ReadingProgressValue.pages(current: 187, total: nil).label, "Page 187, total unknown")
        XCTAssertNil(ReadingProgressValue.pages(current: 187, total: nil).fraction)
        XCTAssertEqual(ReadingProgressValue.percentage(65).fraction, 0.65)
        XCTAssertEqual(ReadingProgressValue.percentage(nil).label, "Percentage unknown")
    }

    func testProgressDisplayClampsOnlyVisualFraction() {
        XCTAssertEqual(ReadingProgressValue.percentage(125).fraction, 1)
        XCTAssertEqual(ReadingProgressValue.percentage(-5).fraction, 0)
        XCTAssertEqual(ReadingProgressValue.pages(current: 20, total: 0).fraction, nil)
    }

    func testFiveTabShellRemainsLocked() {
        XCTAssertEqual(MainTab.allCases.map(\.rawValue), ["Home", "Journal", "Challenges", "Series", "Stats"])
    }

    func testCelebrationQueuePresentsEachRewardOnlyOnce() {
        let event = PresentationCelebration(id: "finish-book:one", kind: .bookCompleted, eyebrow: "BOOK COMPLETED", title: "Finished", message: "Saved", symbol: "book.closed.fill")
        var queue = CelebrationQueue()

        XCTAssertTrue(queue.enqueue(event))
        XCTAssertFalse(queue.enqueue(event))
        XCTAssertEqual(queue.active, event)
        queue.dismiss()
        XCTAssertNil(queue.active)
        XCTAssertFalse(queue.enqueue(event))
    }

    func testCelebrationFactoryUsesSemanticAwardDelta() throws {
        let finish = try XPAward(semanticKey: "finish-book:one", source: .finishBook, amount: 100)

        XCTAssertEqual(CelebrationFactory.next(before: [], after: [finish])?.kind, .bookCompleted)
        XCTAssertNil(CelebrationFactory.next(before: [finish], after: [finish]))
    }

    func testSimultaneousCompletionAchievementAndLevelAreQueuedWithoutDuplicates() throws {
        let before=try [XPAward(semanticKey:"finish-book:seed",source:.finishBook,amount:490)]
        let finish=try XPAward(semanticKey:"finish-book:next",source:.finishBook,amount:100)
        let achievement=try XPAward(semanticKey:"achievement:first",source:.achievement,amount:30)
        let after=before+[finish,achievement]
        let events=CelebrationFactory.events(before:before,after:after)
        XCTAssertTrue(events.contains(where:{$0.kind == .bookCompleted}))
        XCTAssertTrue(events.contains(where:{$0.kind == .achievementUnlocked}))
        var queue=CelebrationQueue()
        for event in events { XCTAssertTrue(queue.enqueue(event)) }
        for event in events { XCTAssertFalse(queue.enqueue(event)) }
        XCTAssertEqual(queue.pending.count,events.count)
        for event in events { XCTAssertEqual(queue.active,event);queue.dismiss() }
        XCTAssertNil(queue.active)
    }

    func testReduceMotionUsesFadeWithinApprovedTiming() {
        XCTAssertEqual(PresentationMotionPolicy.celebrationStyle(reduceMotion: true), .fade)
        XCTAssertEqual(PresentationMotionPolicy.celebrationStyle(reduceMotion: false), .fadeAndScale)
        XCTAssertEqual(PresentationMotionPolicy.celebrationDuration(reduceMotion: true), 0.18)
        XCTAssertEqual(PresentationMotionPolicy.celebrationDuration(reduceMotion: false), 0.24)
    }
}
