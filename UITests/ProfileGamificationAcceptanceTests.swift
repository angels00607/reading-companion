import XCTest

final class ProfileGamificationAcceptanceTests:XCTestCase {
    @MainActor func testPhase7FunctionalAndVisualQA() {
        for (appearance,size) in [("Light","UICTContentSizeCategoryL"),("Dark","UICTContentSizeCategoryL"),("Light","UICTContentSizeCategoryAccessibilityXXXL")] {
            for route in ["profile","quests","achievements","collection","reward"] {
                let app=XCUIApplication();app.launchArguments=["-phase7-fixture","-phase7-screen",route,"-phase0-appearance",appearance,"-UIPreferredContentSizeCategoryName",size];app.launch();XCUIDevice.shared.orientation = .portrait
                let screen = route == "reward" ? app.otherElements["phase1.celebration"] : app.scrollViews["phase7." + route]
                XCTAssertTrue(screen.waitForExistence(timeout:10), "Expected live \(route) screen")
                if route == "quests" {
                    XCTAssertTrue(app.staticTexts["Make time to read"].firstMatch.exists, "The seeded Quests must render; an empty screen cannot pass QA")
                    XCTAssertTrue(app.staticTexts["Turn a few pages"].firstMatch.exists)
                }
                if route == "achievements" {
                    XCTAssertTrue(app.staticTexts["First Chapter"].exists)
                    XCTAssertTrue(app.staticTexts["3 of 3 featured"].exists)
                }
                attach(app,"Phase7-\(appearance)-\(size)-\(route)-top")
                if route != "reward" { app.swipeUp(); app.swipeUp(); attach(app,"Phase7-\(appearance)-\(size)-\(route)-lower") }
                app.terminate()
            }
        }
    }
    @MainActor private func attach(_ app:XCUIApplication,_ name:String){let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)}
}

