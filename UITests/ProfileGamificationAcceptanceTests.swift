import XCTest

final class ProfileGamificationAcceptanceTests: XCTestCase {
    @MainActor func testPassportLabelCorrectionVisualQA() {
        for (appearance,size) in [("Light","UICTContentSizeCategoryL"),("Dark","UICTContentSizeCategoryL"),("Light","UICTContentSizeCategoryAccessibilityXXXL")] {
            let app = XCUIApplication()
            app.launchArguments = ["-phase7-fixture","-phase7-screen","profile","-phase0-appearance",appearance,"-UIPreferredContentSizeCategoryName",size]
            app.launch(); XCUIDevice.shared.orientation = .portrait
            XCTAssertTrue(app.scrollViews["phase7.profile"].waitForExistence(timeout:15))
            let prefix = "Phase7-\(appearance)-\(size)-"
            attach(app,prefix+"profile-top")
            scrollTo(app.descendants(matching:.any)["profile.level"].firstMatch,app)
            attach(app,prefix+"profile-level")
            let favorites = app.staticTexts["Favorite Books \u{00B7} 10 selected"]
            scrollTo(favorites,app); XCTAssertTrue(favorites.exists && favorites.isHittable)
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Â")).firstMatch.exists)
            attach(app,prefix+"profile-favorites")
            app.swipeUp(); app.swipeUp(); attach(app,prefix+"profile-lower")
            app.terminate()
        }
    }
    @MainActor func testCleanProductionLaunchA() {
        let app = XCUIApplication()
        // The quests route deliberately skips presentation seeding, so this remains a
        // clean production lifecycle while isolating the store from earlier UI suites.
        app.launchArguments = ["-phase7-fixture","-phase7-screen","quests"]
        app.launch()
        // Xcode 16.4 can expose SwiftUI ScrollView/Text nodes as Other through the
        // modern AX bridge. The identifiers and labels remain the product contract.
        XCTAssertTrue(app.descendants(matching:.any)["phase7.quests"].waitForExistence(timeout:15))
        XCTAssertTrue(app.descendants(matching:.any)["Capture a reading update"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching:.any)["Make a library choice"].firstMatch.exists)
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
        XCTAssertEqual(app.descendants(matching:.any)["cosmetic.row.background.midnight"].firstMatch.value as? String,"unlocked","Cancel must keep initial equipment unchanged")
        scrollTo(preview,app); preview.tap(); app.buttons["cosmetic.apply"].tap()
        XCTAssertTrue(app.scrollViews["phase7.collection"].waitForExistence(timeout:5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.scrollViews["phase7.collection"].waitForExistence(timeout:15))
        XCTAssertEqual(app.descendants(matching:.any)["cosmetic.row.background.midnight"].firstMatch.value as? String,"equipped")
        let theme = app.buttons["cosmetic.preview.theme.modern-bookish"]
        scrollTo(theme,app); theme.tap()
        XCTAssertTrue(app.buttons["cosmetic.cancel"].waitForExistence(timeout:5)); attach(app,"Phase7-Theme-preview-before-cancel")
        app.buttons["cosmetic.cancel"].tap()
        XCTAssertFalse(app.staticTexts["Modern Bookish · applied surfaces"].exists,"Cancel must keep the original theme")
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
                if route == "achievements" {
                    XCTAssertTrue(app.staticTexts["First Chapter"].exists)
                    XCTAssertTrue(app.staticTexts["3 of 3 featured"].exists,"Exactly three genuinely unlocked selections must persist")
                }
                attach(app,"Phase7-\(appearance)-\(size)-\(route)-top")
                if route == "profile" {
                    scrollTo(app.descendants(matching:.any)["profile.level"].firstMatch,app)
                    attach(app,"Phase7-\(appearance)-\(size)-profile-level")
                }
                if route == "quests" {
                    for cadence in ["WEEKLY","MONTHLY"] {
                        scrollTo(app.staticTexts[cadence].firstMatch,app)
                        attach(app,"Phase7-\(appearance)-\(size)-quests-"+cadence.lowercased())
                    }
                    let reroll = app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","quest.reroll.")).firstMatch
                    scrollTo(reroll,app); XCTAssertTrue(reroll.exists && reroll.isEnabled); reroll.tap()
                    XCTAssertTrue(app.staticTexts["Reroll unavailable · returns next period"].firstMatch.exists)
                    attach(app,"Phase7-\(appearance)-\(size)-reroll-consumed")
                    app.buttons["phase7.recordActivity"].tap()
                    XCTAssertTrue(app.staticTexts["Completed"].firstMatch.waitForExistence(timeout:5))
                    attach(app,"Phase7-\(appearance)-\(size)-quest-progress")
                    app.buttons["phase7.recordActivity"].tap()
                    attach(app,"Phase7-\(appearance)-\(size)-quest-completed")
                }
                if route != "reward" { app.swipeUp(); app.swipeUp(); attach(app,"Phase7-\(appearance)-\(size)-\(route)-lower") }
                if route == "achievements" {
                    scrollTo(app.buttons["Featured"].firstMatch,app)
                    attach(app,"Phase7-\(appearance)-\(size)-featured-selection")
                    scrollTo(app.staticTexts["Gentle Momentum"],app)
                    attach(app,"Phase7-\(appearance)-\(size)-achievement-progress")
                }
                if route == "collection" {
                    scrollTo(app.descendants(matching:.any)["cosmetic.row.background.midnight"].firstMatch,app)
                    attach(app,"Phase7-\(appearance)-\(size)-unlocked-cosmetic")
                    scrollTo(app.descendants(matching:.any)["cosmetic.row.accent.berry"].firstMatch,app)
                    attach(app,"Phase7-\(appearance)-\(size)-locked-cosmetic")
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
        for _ in 0..<20 {
            if element.exists && element.isHittable { return }
            if element.exists && !element.isEnabled && app.frame.intersects(element.frame) { return }
            let preview = app.scrollViews["phase7.preview"]
            let surface = preview.exists ? preview : app.scrollViews.firstMatch
            if element.exists && element.frame.minY < surface.frame.minY+40 { surface.swipeDown() } else { surface.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable,"Required production control must be reachable")
    }
    @MainActor private func attach(_ app:XCUIApplication,_ name:String){let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)}
}
