import XCTest
import UIKit

final class FoundationAcceptanceTests: XCTestCase {
    @MainActor
    func testLightDefault() throws { try audit(style: "Light", category: "UICTContentSizeCategoryL", orientation: .portrait) }

    @MainActor
    func testDarkDefault() throws { try audit(style: "Dark", category: "UICTContentSizeCategoryL", orientation: .portrait) }

    @MainActor
    func testSystemFollowsSimulatorDarkAppearance() throws {
        // CI sets the simulator appearance to Dark before launching the test host.
        try audit(style: "System", category: "UICTContentSizeCategoryL", orientation: .portrait)
    }

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
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", category]
        if style != "System" { app.launchArguments += ["-phase0-appearance", style] }
        app.launch()
        XCUIDevice.shared.orientation = orientation
        defer { app.terminate() }
        let tabs = ["Home", "Journal", "Challenges", "Series", "Stats"]
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "foundationTab.")).count, tabs.count)
        for name in tabs {
            let button = app.buttons["foundationTab." + name]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertEqual(button.label, name)
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            button.tap()
            XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Foundation preview"].exists)
            let capture = app.screenshot()
            // Verify rendered appearance, not just the requested launch argument.
            let bitmap = try XCTUnwrap(capture.image.cgImage)
            let bytes = try XCTUnwrap(bitmap.dataProvider?.data)
            let pixelSize = bitmap.bitsPerPixel / 8
            let offset = (bitmap.height / 2) * bitmap.bytesPerRow + 2 * pixelSize
            let buffer = try XCTUnwrap(CFDataGetBytePtr(bytes))
            let actual = (0..<pixelSize).map { Int(buffer[offset + $0]) }.filter { $0 != 255 }.sorted()
            let expected = style == "Light" ? [248, 250, 251] : [3, 11, 25]
            XCTAssertEqual(actual, expected.sorted(), "Rendered \(style) background must match its semantic token")
            let screenshot = XCTAttachment(screenshot: capture)
            screenshot.name = "\(name)-\(style)-\(category)-\(XCUIDevice.shared.orientation.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            // No issue filtering: findings fail the acceptance check.
            try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion,
                .sufficientElementDescription, .textClipped, .trait])
        }
    }
}
