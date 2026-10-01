import XCTest

final class FoundationAcceptanceTests: XCTestCase {
    @MainActor
    func testLightDefault() throws { try audit(style: "Light", category: "UICTContentSizeCategoryL", orientation: .portrait) }

    @MainActor
    func testDarkDefault() throws { try audit(style: "Dark", category: "UICTContentSizeCategoryL", orientation: .portrait) }

    @MainActor
    func testLightAccessibilityXXXL() throws { try audit(style: "Light", category: "UICTContentSizeCategoryAccessibilityXXXL", orientation: .portrait) }

    @MainActor
    func testDarkAccessibilityXXXLLandscape() throws {
        try audit(style: "Dark", category: "UICTContentSizeCategoryAccessibilityXXXL", orientation: .landscapeLeft)
    }

    @MainActor
    private func audit(style: String, category: String, orientation: UIDeviceOrientation) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleInterfaceStyle", style,
                               "-UIPreferredContentSizeCategoryName", category]
        app.launch()
        XCUIDevice.shared.orientation = orientation
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
