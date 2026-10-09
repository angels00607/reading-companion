import XCTest

final class NotificationSettingsAcceptanceTests:XCTestCase {
    @MainActor func testSettingsExposeDefaultsAndAttentionExplanation() throws {
        let app=XCUIApplication();app.launchArguments=["-phase10c-fixture","-phase0-appearance","Light","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"];app.launch();defer{app.terminate()}
        XCTAssertTrue(app.otherElements["notifications.settings"].waitForExistence(timeout:10))
        XCTAssertEqual(app.switches["notifications.series_releases"].value as? String,"1")
        XCTAssertEqual(app.switches["notifications.challenges"].value as? String,"0")
        XCTAssertTrue(app.staticTexts["Turning notifications off never removes or resolves Needs Attention items."].exists)
        XCTAssertTrue(app.staticTexts["No default is defined for Achievements & Levels. Changing this switch records your explicit choice."].exists)
    }
}
