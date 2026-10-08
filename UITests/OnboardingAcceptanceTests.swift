import XCTest

final class OnboardingAcceptanceTests: XCTestCase {
    func testFreshOnboardingCompletesAndDoesNotReappear() {
        let token = UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-phase7-acceptance-store", token]
        app.launch()

        XCTAssertTrue(app.buttons["onboarding.welcome.continue"].waitForExistence(timeout: 5))
        app.buttons["onboarding.welcome.continue"].tap()
        let year = app.textFields["onboarding.readingSince"]
        XCTAssertTrue(year.waitForExistence(timeout: 2))
        year.tap()
        year.typeText("2020")
        app.swipeDown()
        app.buttons["onboarding.readingSince.continue"].tap()
        app.buttons["onboarding.edition.en"].tap()
        app.buttons["onboarding.edition.continue"].tap()
        app.buttons["onboarding.fresh"].tap()
        XCTAssertTrue(app.buttons["onboarding.finish"].waitForExistence(timeout: 2))
        app.buttons["onboarding.finish"].tap()
        XCTAssertTrue(app.staticTexts["foundationTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["foundationTitle"].label, "Home")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["foundationTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.welcome.continue"].exists)
    }
}
