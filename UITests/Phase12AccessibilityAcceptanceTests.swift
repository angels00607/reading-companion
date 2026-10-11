import XCTest
import UIKit

final class Phase12AccessibilityAcceptanceTests: XCTestCase {
    private let fixtureArguments = [
        "-phase2-fixture", "-phase3-fixture", "-phase4-fixture", "-phase5-fixture",
        "-phase6-fixture", "-phase7-fixture"
    ]

    @MainActor
    func testStandardFiveTabAndSecondaryFlowAudit() throws {
        try auditFiveTabs(appearance: "Light", landscapeTab: nil)
        try auditSecondaryScreens(appearance: "Dark")
    }

    @MainActor
    func testAccessibilityXXXLFiveTabAndLandscapeAudit() throws {
        try auditFiveTabs(appearance: "Dark", landscapeTab: "Stats")
        try auditSecondaryScreens(appearance: "Light")
    }

    @MainActor
    func testKeyboardActionsRemainReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-phase2-fixture", "-phase2-screen", "Manual Add", "-phase0-appearance", "Light"]
        app.launch()
        defer { app.terminate() }

        let field = app.textFields["books.field.Title"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        let done = app.buttons["books.keyboardDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable)
        XCTAssertGreaterThanOrEqual(done.frame.width.rounded(), 44)
        XCTAssertGreaterThanOrEqual(done.frame.height.rounded(), 44)
        let submit = app.buttons["books.manual.continue"]
        for _ in 0..<6 where !submit.isHittable { app.swipeUp() }
        XCTAssertTrue(submit.isHittable, "The validation action must remain reachable while the keyboard is open")
    }

    @MainActor
    private func auditFiveTabs(appearance: String, landscapeTab: String?) throws {
        let app = XCUIApplication()
        app.launchArguments = fixtureArguments + ["-phase0-appearance", appearance]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["foundationTab.Home"].waitForExistence(timeout: 15))

        let representatives = [
            "Home": "books.search",
            "Journal": "journal.startSession",
            "Challenges": "challenges.year",
            "Series": "series.search",
            "Stats": "stats.mode"
        ]
        for tab in ["Home", "Journal", "Challenges", "Series", "Stats"] {
            let button = app.buttons["foundationTab." + tab]
            XCTAssertTrue(button.exists)
            XCTAssertEqual(button.label, tab)
            XCTAssertGreaterThanOrEqual(button.frame.width.rounded(), 44)
            XCTAssertGreaterThanOrEqual(button.frame.height.rounded(), 44)
            button.tap()
            XCTAssertTrue(app.descendants(matching: .any)[representatives[tab]!].waitForExistence(timeout: 10))
            if tab == landscapeTab { XCUIDevice.shared.orientation = .landscapeLeft }
            try runAudit(app, context: "\(appearance)-\(tab)" + (tab == landscapeTab ? "-Landscape" : ""))
            if tab == landscapeTab { XCUIDevice.shared.orientation = .portrait }
        }
    }

    @MainActor
    private func auditSecondaryScreens(appearance: String) throws {
        let cases: [([String], String)] = [
            (["-phase7-fixture", "-phase7-screen", "achievements"], "phase7.achievements"),
            (["-phase10b-fixture"], "attention.screen"),
            (["-phase2-fixture", "-phase2-screen", "Manual Add"], "books.manual.continue")
        ]
        for (arguments, representative) in cases {
            let app = XCUIApplication()
            app.launchArguments = arguments + ["-phase0-appearance", appearance]
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)[representative].waitForExistence(timeout: 15))
            try runAudit(app, context: "\(appearance)-\(representative)")
            app.terminate()
        }
    }

    @MainActor
    private func runAudit(_ app: XCUIApplication, context: String) throws {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Phase12-" + context
        attachment.lifetime = .keepAlways
        add(attachment)
        do {
            try app.performAccessibilityAudit(for: [
                .contrast, .dynamicType, .hitRegion, .sufficientElementDescription,
                .textClipped, .trait
            ])
        } catch {
            XCTFail("Accessibility audit failed for \(context): \(error)")
        }
    }
}
