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
            if size == "UICTContentSizeCategoryL" {
                app.buttons["Waiting"].tap()
                app.buttons["series.sort"].tap(); app.buttons["Alphabetical"].tap()
                capture(app, "\(appearance)-Search-Filter-Sort")
                app.buttons["Completed"].tap()
                capture(app, "\(appearance)-Completed-Selected")
                app.buttons["All"].tap()
            }
            app.swipeUp(); capture(app, "\(appearance)-\(size)-List-lower")
            app.swipeDown()
            let row = app.buttons.containing(.staticText, identifier: "The Extremely Long Chronicle of the Moonlit Archive and Its Keepers").firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
            XCTAssertTrue(app.staticTexts["Timeline"].waitForExistence(timeout: 5))
            capture(app, "\(appearance)-\(size)-Series-Page")
            app.swipeUp(); capture(app, "\(appearance)-\(size)-Timeline")
            if size == "UICTContentSizeCategoryL" {
                let attention = app.buttons.containing(.staticText, identifier: "Review position").firstMatch
                for _ in 0..<5 where !attention.isHittable { app.swipeUp() }
                if attention.isHittable { attention.tap(); XCTAssertTrue(app.buttons["Keep"].waitForExistence(timeout: 5)); capture(app, "\(appearance)-Current-Proposed"); app.buttons["Keep"].tap(); capture(app, "\(appearance)-Rejected-Suppressed") }
                for _ in 0..<14 { app.swipeUp() }
                capture(app, "\(appearance)-Timeline-End-25")
            }
            app.terminate()
        }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Phase4-" + name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
