import XCTest

final class JournalAcceptanceTests: XCTestCase {
    @MainActor func testJournalVisualQA() {
        for (appearance, size) in [("Light","UICTContentSizeCategoryL"),("Dark","UICTContentSizeCategoryL"),("Light","UICTContentSizeCategoryAccessibilityXXXL")] {
            let app = XCUIApplication()
            app.launchArguments = ["-phase3-fixture","-phase0-appearance",appearance,"-UIPreferredContentSizeCategoryName",size]
            app.launch(); XCUIDevice.shared.orientation = .portrait
            let tab = app.buttons["foundationTab.Journal"]
            XCTAssertTrue(tab.waitForExistence(timeout: 10)); tab.tap()
            XCTAssertTrue(app.staticTexts["My Journal · Volume 1"].waitForExistence(timeout: 10))
            capture(app, "\(appearance)-\(size)-Inbox")
            app.swipeUp(); capture(app, "\(appearance)-\(size)-Inbox-lower")
            if appearance == "Light" && size == "UICTContentSizeCategoryL" {
                let ready = app.buttons.containing(.staticText, identifier: "Ready for the Next Journal Session").firstMatch
                if ready.exists { ready.tap(); capture(app, "Light-Book-Review-Ready"); app.navigationBars.buttons.firstMatch.tap() }
                let pending = app.buttons.containing(.staticText, identifier: "A Pending Review").firstMatch
                if pending.exists { pending.tap(); capture(app, "Light-Book-Review-incomplete"); app.swipeUp(); capture(app, "Light-Favorite-Quotes"); app.navigationBars.buttons.firstMatch.tap() }
                let corrections = app.buttons["journal.corrections"]
                for _ in 0..<6 where !corrections.isHittable { app.swipeUp() }
                XCTAssertTrue(corrections.isHittable); corrections.tap()
                XCTAssertTrue(app.staticTexts["Summary"].waitForExistence(timeout: 5)); capture(app, "Light-Journal-Correction")
                if app.buttons["Mark corrected"].exists { app.buttons["Mark corrected"].tap(); capture(app, "Light-Journal-Correction-resolved") }
                app.navigationBars.buttons.firstMatch.tap()
                for _ in 0..<4 where !app.buttons["journal.startSession"].isHittable { app.swipeDown() }
                if app.buttons["journal.startSession"].isHittable { app.buttons["journal.startSession"].tap(); XCTAssertTrue(app.buttons["journal.copied"].waitForExistence(timeout: 5)); capture(app, "Light-Journal-Session") }
            }
            app.terminate()
        }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Phase3-" + name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
