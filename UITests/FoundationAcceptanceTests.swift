import XCTest

final class FoundationAcceptanceTests: XCTestCase {
    @MainActor
    func testLightDefault() throws { try audit(style: "Light", category: "UICTContentSizeCategoryL") }

    @MainActor
    func testDarkDefault() throws { try audit(style: "Dark", category: "UICTContentSizeCategoryL") }

    @MainActor
    func testLightAccessibilityXXXL() throws { try audit(style: "Light", category: "UICTContentSizeCategoryAccessibilityXXXL") }

    @MainActor
    func testDarkAccessibilityXXXLLandscape() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        try audit(style: "Dark", category: "UICTContentSizeCategoryAccessibilityXXXL")
    }

    @MainActor
    private func audit(style: String, category: String) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleInterfaceStyle", style,
                               "-UIPreferredContentSizeCategoryName", category]
        app.launch()
        defer { app.terminate() }
        let tabs = ["Home", "Journal", "Challenges", "Series", "Stats"]
        XCTAssertEqual(app.tabBars.buttons.count, tabs.count)
        for name in tabs {
            let button = app.tabBars.buttons[name]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertEqual(button.label, name)
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            button.tap()
            XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Foundation preview"].exists)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "\(name)-\(style)-\(category)-\(XCUIDevice.shared.orientation.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            // No issue filtering: findings fail the acceptance check.
            try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion,
                .sufficientElementDescription, .textClipped, .trait])
        }
    }
}
