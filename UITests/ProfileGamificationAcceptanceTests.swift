import XCTest

final class ProfileGamificationAcceptanceTests: XCTestCase {
    @MainActor func testCleanProductionLaunchA() {
        let app = XCUIApplication()
        app.launchArguments = ["-phase7-acceptance-store",UUID().uuidString,"-phase7-screen","quests"]
        app.launch()
        XCTAssertTrue(app.scrollViews["phase7.quests"].waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts["Capture a reading update"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Make a library choice"].firstMatch.exists)
        // Repository acceptance proves exact 2/3/3; native clean launch proves no seed dependency.
        attach(app,"Phase7-Clean-production-launch")
        app.terminate()
    }
    @MainActor func testProductionCollectionCancelApplyReopenHIJ() {
        let token = UUID().uuidString, app = XCUIApplication()
        app.launchArguments = ["-phase7-acceptance-store",token,"-phase7-screen","collection"]
        app.launch()
        XCTAssertTrue(app.scrollViews["phase7.collection"].waitForExistence(timeout:15))
        let locked = app.buttons["cosmetic.preview.accent.berry"]
        scrollTo(locked,app)
        XCTAssertTrue(locked.exists); XCTAssertFalse(locked.isEnabled)
        let preview = app.buttons["cosmetic.preview.background.midnight"]
        scrollTo(preview,app); preview.tap()
        XCTAssertTrue(app.buttons["cosmetic.cancel"].waitForExistence(timeout:5))
        attach(app,"Phase7-Cosmetic-preview-before-cancel")
        app.buttons["cosmetic.cancel"].tap()
        XCTAssertTrue(app.scrollViews["phase7.collection"].waitForExistence(timeout:5))
        scrollTo(preview,app); preview.tap(); app.buttons["cosmetic.apply"].tap()
        XCTAssertTrue(app.scrollViews["phase7.collection"].waitForExistence(timeout:5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.scrollViews["phase7.collection"].waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts["Equipped"].firstMatch.exists)
        let theme = app.buttons["cosmetic.preview.theme.modern-bookish"]
        scrollTo(theme,app); theme.tap()
        XCTAssertTrue(app.buttons["cosmetic.cancel"].waitForExistence(timeout:5)); attach(app,"Phase7-Theme-preview-before-cancel")
        app.buttons["cosmetic.cancel"].tap()
        scrollTo(theme,app); theme.tap(); app.buttons["cosmetic.apply"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.scrollViews["phase7.collection"].waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts["Modern Bookish · applied surfaces"].exists)
        attach(app,"Phase7-Theme-applied-reopened")
        app.terminate()
    }
    @MainActor func testPhase7FunctionalAndVisualQA() {
        for (appearance,size) in [("Light","UICTContentSizeCategoryL"),("Dark","UICTContentSizeCategoryL"),("Light","UICTContentSizeCategoryAccessibilityXXXL")] {
            for route in ["profile","quests","achievements","collection","reward"] {
                let app=XCUIApplication();app.launchArguments=["-phase7-fixture","-phase7-screen",route,"-phase0-appearance",appearance,"-UIPreferredContentSizeCategoryName",size];app.launch();XCUIDevice.shared.orientation = .portrait
                let screen = route == "reward" ? app.otherElements["phase1.celebration"] : app.scrollViews["phase7." + route]
                XCTAssertTrue(screen.waitForExistence(timeout:15),"Expected live \(route) screen")
                if route == "quests" { XCTAssertTrue(app.staticTexts["Completed"].firstMatch.exists) }
                if route == "achievements" { XCTAssertTrue(app.staticTexts["First Chapter"].exists) }
                attach(app,"Phase7-\(appearance)-\(size)-\(route)-top")
                if route != "reward" { app.swipeUp(); app.swipeUp(); attach(app,"Phase7-\(appearance)-\(size)-\(route)-lower") }
                if route == "collection" {
                    let theme = app.buttons["cosmetic.preview.theme.modern-bookish"]
                    scrollTo(theme,app); theme.tap(); XCTAssertTrue(app.buttons["cosmetic.cancel"].waitForExistence(timeout:5))
                    attach(app,"Phase7-\(appearance)-\(size)-theme-preview")
                    scrollTo(app.buttons["cosmetic.apply"],app); app.buttons["cosmetic.apply"].tap()
                    XCTAssertTrue(app.scrollViews["phase7.collection"].waitForExistence(timeout:5))
                    for _ in 0..<10 { app.swipeDown() }
                    attach(app,"Phase7-\(appearance)-\(size)-theme-applied")
                }
                app.terminate()
            }
        }
    }
    @MainActor private func scrollTo(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<12 { if element.exists && element.isHittable { return }; app.swipeDown() }
        for _ in 0..<18 { if element.exists && element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.exists && element.isHittable,"Required production control must be reachable")
    }
    @MainActor private func attach(_ app:XCUIApplication,_ name:String){let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)}
}
