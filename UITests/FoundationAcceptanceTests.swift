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
        continueAfterFailure = true
        let app = XCUIApplication()
        // CI sets the real simulator category; launch defaults must not freeze
        // Dynamic Type while the accessibility auditor changes categories.
        app.launchArguments = ["-phase0-diagnostics"]
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
            let scroll = app.scrollViews["foundationTabScroll"]
            for _ in 0..<6 where scroll.exists && !scroll.frame.contains(button.frame) { scroll.swipeLeft() }
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            button.tap()
            XCTAssertTrue(app.staticTexts["foundationTitle"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["foundationTitle"].label, name)
            XCTAssertTrue(app.staticTexts["Phase 1 component preview data"].exists)
            let representativeComponent = [
                "Home": "phase1.bookRow", "Journal": "phase1.bottomSheet",
                "Challenges": "phase1.dataChangeReview", "Series": "phase1.attentionRow",
                "Stats": "phase1.accessibleChart"
            ][name]!
            XCTAssertTrue(app.descendants(matching: .any)[representativeComponent].waitForExistence(timeout: 3))
            let capture = app.screenshot()
            // Verify rendered appearance, not just the requested launch argument.
            let bitmap = try XCTUnwrap(capture.image.cgImage)
            let bytes = try XCTUnwrap(bitmap.dataProvider?.data)
            let pixelSize = bitmap.bitsPerPixel / 8
            let buffer = try XCTUnwrap(CFDataGetBytePtr(bytes))
            let expected = (style == "Light" ? [248, 250, 251] : [3, 11, 25]).sorted()
            var samples = 0
            var matching = 0
            for y in stride(from: 0, to: bitmap.height, by: 16) {
                for x in stride(from: 0, to: bitmap.width, by: 16) {
                    let offset = y * bitmap.bytesPerRow + x * pixelSize
                    let actual = (0..<pixelSize).map { Int(buffer[offset + $0]) }.filter { $0 != 255 }.sorted()
                    samples += 1
                    if actual == expected { matching += 1 }
                }
            }
            XCTAssertGreaterThan(Double(matching) / Double(samples), 0.25,
                                 "Rendered \(style) must contain its semantic background")
            let screenshot = XCTAttachment(screenshot: capture)
            screenshot.name = "\(name)-\(style)-\(category)-\(XCUIDevice.shared.orientation.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            recordLiveElements(app, context: "before-" + name + "-" + style + "-" + category)
            var findingNumber = 0
            // No issue filtering: findings fail the acceptance check.
            do {
                try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion,
                .sufficientElementDescription, .textClipped, .trait]) { issue in
                    findingNumber += 1
                    if findingNumber == 1 {
                        self.recordLiveElements(app, context: "during-" + name + "-" + style + "-" + category)
                    }
                print("AUDIT ISSUE: \(issue.detailedDescription)")
                print("AUDIT ELEMENT: \(issue.element?.debugDescription ?? "unknown")")
                    return false
                }
            } catch {
                XCTFail("Accessibility audit failed for \(name), \(style), \(category): \(error)")
            }
            recordLiveElements(app, context: "after-" + name + "-" + style + "-" + category)
        }
    }

    @MainActor
    private func recordLiveElements(_ app: XCUIApplication, context: String) {
        var rows: [[String: Any]] = []
        for element in app.buttons.allElementsBoundByIndex + app.staticTexts.allElementsBoundByIndex {
            rows.append(["identifier": element.identifier, "label": element.label,
                "frame": String(describing: element.frame), "selected": element.isSelected,
                "enabled": element.isEnabled, "type": element.elementType.rawValue])
        }
        let payload: [String: Any] = ["context": context, "time": Date().timeIntervalSince1970,
            "orientation": XCUIDevice.shared.orientation.rawValue, "elements": rows,
            "tree": app.debugDescription]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "Live-elements-" + context
            attachment.lifetime = .keepAlways
            add(attachment)
            print("LIVE ELEMENTS: " + String(decoding: data, as: UTF8.self))
        } catch { XCTFail("Could not capture live diagnostic evidence: \(error)") }
    }
}
