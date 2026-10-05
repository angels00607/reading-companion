import XCTest

final class SeriesAcceptanceTests: XCTestCase {
    @MainActor func testSeriesAcceptanceAndVisualQA() {
        for (appearance, size) in [("Light","UICTContentSizeCategoryL"),("Dark","UICTContentSizeCategoryL"),("Light","UICTContentSizeCategoryAccessibilityXXXL")] {
            let app = XCUIApplication()
            app.launchArguments = ["-phase4-fixture","-phase0-appearance",appearance,"-UIPreferredContentSizeCategoryName",size]
            app.launch(); XCUIDevice.shared.orientation = .portrait
            let tab = app.buttons["foundationTab.Series"]
            XCTAssertTrue(tab.waitForExistence(timeout: 10)); tab.tap()
            XCTAssertTrue(app.textFields["series.search"].waitForExistence(timeout: 5))
            capture(app, "\(appearance)-\(size)-List")
            app.swipeUp(); capture(app, "\(appearance)-\(size)-List-lower")
            app.swipeDown()
            let row = app.buttons.containing(.staticText, identifier: "The Extremely Long Chronicle of the Moonlit Archive and Its Keepers").firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
            XCTAssertTrue(app.staticTexts["Timeline"].waitForExistence(timeout: 5))
            capture(app, "\(appearance)-\(size)-Series-Page")
            app.swipeUp(); capture(app, "\(appearance)-\(size)-Timeline")
            if size == "UICTContentSizeCategoryL" {
                let attention = app.buttons.containing(.staticText, identifier: "Review position").firstMatch
                if attention.exists { attention.tap(); XCTAssertTrue(app.staticTexts["CURRENT"].waitForExistence(timeout: 5)); capture(app, "\(appearance)-Current-Proposed"); app.buttons["Keep"].tap() }
            }
            app.terminate()
        }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Phase4-" + name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
