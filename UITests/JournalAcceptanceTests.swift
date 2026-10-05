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
                if ready.exists { ready.tap(); waitForAnimations(); capture(app, "Light-Book-Review-Ready"); app.navigationBars.buttons.firstMatch.tap(); waitForAnimations() }
                let pending = app.buttons.containing(.staticText, identifier: "A Pending Review").firstMatch
                if pending.exists { pending.tap(); waitForAnimations(); capture(app, "Light-Book-Review-incomplete"); app.swipeUp(); capture(app, "Light-Favorite-Quotes"); app.navigationBars.buttons.firstMatch.tap(); waitForAnimations() }
                let corrections = app.buttons["journal.corrections"]
                for _ in 0..<6 where !corrections.isHittable { app.swipeUp() }
                XCTAssertTrue(corrections.isHittable); corrections.tap()
                XCTAssertTrue(app.staticTexts["Summary"].waitForExistence(timeout: 5)); capture(app, "Light-Journal-Correction")
                let resolve = app.buttons["I've corrected my journal"].firstMatch
                if resolve.exists { resolve.tap(); capture(app, "Light-Journal-Correction-resolved") }
                app.navigationBars.buttons.firstMatch.tap()
                for _ in 0..<4 where !app.buttons["journal.startSession"].isHittable { app.swipeDown() }
                if app.buttons["journal.startSession"].isHittable { app.buttons["journal.startSession"].tap(); XCTAssertTrue(app.buttons["journal.copied"].waitForExistence(timeout: 5)); capture(app, "Light-Journal-Session") }
            }
            if appearance == "Light" && size == "UICTContentSizeCategoryAccessibilityXXXL" {
                let ready = app.buttons.containing(.staticText, identifier: "Ready for the Next Journal Session").firstMatch
                if ready.exists { ready.tap(); waitForAnimations(); capture(app, "AccessibilityXXXL-Book-Review-Ready"); app.navigationBars.buttons.firstMatch.tap(); waitForAnimations() }
                let session = app.buttons["journal.startSession"]
                for _ in 0..<6 where !session.isHittable { app.swipeUp() }
                if session.isHittable { session.tap(); XCTAssertTrue(app.buttons["journal.copied"].waitForExistence(timeout: 5)); capture(app, "AccessibilityXXXL-Journal-Session") }
            }
            app.terminate()
        }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Phase3-" + name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func waitForAnimations() { RunLoop.current.run(until: Date().addingTimeInterval(0.6)) }
}
