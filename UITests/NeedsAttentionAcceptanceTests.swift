import XCTest

final class NeedsAttentionAcceptanceTests:XCTestCase {
    @MainActor func testCentralListFiltersAndImportVisibility() throws {
        let app=XCUIApplication()
        app.launchArguments=["-phase10b-fixture","-phase0-appearance","Light"]
        app.launch();defer{app.terminate()}
        XCTAssertTrue(app.otherElements["attention.screen"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Review imported data"].exists,"Import appears in All")
        app.buttons["Books"].tap()
        XCTAssertTrue(app.staticTexts["Review book information"].waitForExistence(timeout:3))
        XCTAssertFalse(app.staticTexts["Review imported data"].exists,"Import is intentionally not a separate filter")
        XCTAssertEqual(app.tabBars.count,0,"The presentation route must not introduce a sixth tab")
    }
}
