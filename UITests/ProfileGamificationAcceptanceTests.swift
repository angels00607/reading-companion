import XCTest

final class ProfileGamificationAcceptanceTests:XCTestCase {
    @MainActor func testPhase7FunctionalAndVisualQA() {
        for (appearance,size) in [("Light","UICTContentSizeCategoryL"),("Dark","UICTContentSizeCategoryL"),("Light","UICTContentSizeCategoryAccessibilityXXXL")] {
            for route in ["profile","quests","achievements","collection","reward"] {
                let app=XCUIApplication();app.launchArguments=["-phase7-fixture","-phase7-screen",route,"-phase0-appearance",appearance,"-UIPreferredContentSizeCategoryName",size];app.launch();XCUIDevice.shared.orientation = .portrait
                XCTAssertTrue(app.otherElements[route == "profile" ? "phase7.profile" : route == "quests" ? "phase7.quests" : route == "achievements" ? "phase7.achievements" : route == "collection" ? "phase7.collection" : "phase1.celebration"].waitForExistence(timeout:10))
                let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="Phase7-\(appearance)-\(size)-\(route)";attachment.lifetime = .keepAlways;add(attachment);app.terminate()
            }
        }
    }
}
