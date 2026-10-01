import XCTest
@testable import ReadingUI

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
}
