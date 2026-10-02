import XCTest
import UIKit

final class BooksCoreAcceptanceTests: XCTestCase {
    @MainActor func testOfficialAcceptanceFlow() throws {
        let app = XCUIApplication(); app.launchArguments = ["-phase2-fixture","-phase0-appearance","Light"]
        app.launch(); defer { app.terminate() }
        XCTAssertTrue(app.buttons["books.search"].waitForExistence(timeout: 10)); app.buttons["books.search"].tap()
        setField(app, "Search title or author", "fixture")
        let result = app.buttons["books.external.work-1"]
        XCTAssertTrue(result.waitForExistence(timeout: 10)); capture(app, "Official-search-results"); result.tap()
        let edition = app.buttons["books.edition.edition-en"]
        XCTAssertTrue(edition.waitForExistence(timeout: 5)); edition.tap()
        app.buttons["books.add"].tap()
        XCTAssertTrue(app.buttons["books.openAdded"].waitForExistence(timeout: 5)); app.buttons["books.openAdded"].tap()
        capture(app,"Official-To-Read"); app.buttons["books.start"].tap()
        XCTAssertTrue(app.buttons["books.confirmStart"].waitForExistence(timeout: 5)); app.buttons["books.confirmStart"].tap()
        for (page,expectDelta) in [(183,false),(257,true)] {
            XCTAssertTrue(app.buttons["books.update"].waitForExistence(timeout: 5)); app.buttons["books.update"].tap()
            setField(app,"Current page",String(page)); tap(app,"books.saveProgress")
            XCTAssertTrue(app.buttons["books.update"].waitForExistence(timeout: 5))
            if expectDelta { XCTAssertTrue(app.staticTexts["+74 pages"].waitForExistence(timeout: 5)); capture(app,"Official-plus-74") }
        }
        app.buttons["books.update"].tap(); setField(app,"Current page","400"); tap(app,"books.saveProgress")
        XCTAssertTrue(app.buttons["books.confirmFinish"].waitForExistence(timeout: 5)); capture(app,"Official-finish-confirmation")
        XCTAssertFalse(app.staticTexts["Read"].exists)
        app.buttons["books.confirmFinish"].tap()
        XCTAssertTrue(app.staticTexts["Read"].waitForExistence(timeout: 5)); capture(app,"Official-Read")
    }
    @MainActor func testLightVisualQA() throws { try visualQA(style: "Light", category: "UICTContentSizeCategoryL") }
    @MainActor func testDarkVisualQA() throws { try visualQA(style: "Dark", category: "UICTContentSizeCategoryL") }
    @MainActor func testCompactAccessibilityVisualQA() throws { try visualQA(style: "Light", category: "UICTContentSizeCategoryAccessibilityXXXL") }
    @MainActor private func visualQA(style: String, category: String) throws {
        let routes = ["Global Search","Search Results","Edition Selection","Manual Add","My Books","To Read","Currently Reading","Update Progress Page","Update Progress Percentage","Finish confirmation","DNF","Reading History","Edit Book Info"]
        for route in routes {
            let app = XCUIApplication()
            app.launchArguments = ["-phase2-fixture","-phase2-screen",route,"-phase0-appearance",style,"-UIPreferredContentSizeCategoryName",category]
            app.launch(); XCUIDevice.shared.orientation = .portrait
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 10))
            if route == "Search Results" { setField(app,"Search title or author","fixture"); XCTAssertTrue(app.buttons["books.external.work-1"].waitForExistence(timeout: 10)) }
            if route == "Edition Selection" { XCTAssertTrue(app.buttons["books.edition.edition-en"].waitForExistence(timeout: 10)) }
            if route == "Finish confirmation" { XCTAssertTrue(app.buttons["books.confirmFinish"].waitForExistence(timeout: 10)) }
            for button in app.buttons.allElementsBoundByIndex where button.identifier.hasPrefix("books.") && button.isHittable {
                XCTAssertFalse(button.label.isEmpty)
                XCTAssertGreaterThanOrEqual(button.frame.width,44)
                XCTAssertGreaterThanOrEqual(button.frame.height,44)
            }
            capture(app,style + "-" + category + "-" + route + "-top")
            app.swipeUp(); capture(app,style + "-" + category + "-" + route + "-lower")
            app.terminate()
        }
    }
    @MainActor private func setField(_ app: XCUIApplication, _ label: String, _ text: String) {
        let id = "books.field." + label
        let field = app.textFields[id].exists ? app.textFields[id] : app.textViews[id]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        let old = field.value as? String ?? ""
        // Tapping the label-side of a populated field can place the caret at its
        // beginning. Delete from the actual end, then verify the live value;
        // otherwise the fixture can enter "400257" instead of replacing "257".
        if !old.isEmpty && old != label {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old == label ? 0 : old.count) + text)
        XCTAssertEqual(field.value as? String, text, "The live field must contain the requested test input")
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
    }
    @MainActor private func tap(_ app: XCUIApplication, _ id: String) {
        let button = app.buttons[id]
        for _ in 0..<6 where !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.isHittable); button.tap()
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Phase2-" + name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
