import XCTest

final class ChallengesAcceptanceTests: XCTestCase {
    @MainActor private func launch(_ route: String? = nil, appearance: String = "Light", size: String = "UICTContentSizeCategoryL") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-phase5-fixture","-phase0-appearance",appearance,"-UIPreferredContentSizeCategoryName",size]
        if let route { app.launchArguments += ["-phase5-screen",route] }
        app.launch(); XCUIDevice.shared.orientation = .portrait
        if route == nil { let tab = app.buttons["foundationTab.Challenges"]; XCTAssertTrue(tab.waitForExistence(timeout:10)); tab.tap() }
        return app
    }
    @MainActor private func tap(_ app: XCUIApplication, _ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout:8))
        for _ in 0..<25 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable, "Control must remain reachable: \(element.identifier)")
        XCTAssertGreaterThanOrEqual(element.frame.width,44)
        XCTAssertGreaterThanOrEqual(element.frame.height,44)
        element.tap()
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot:app.screenshot()); a.name = "Phase5-" + name; a.lifetime = .keepAlways; add(a)
    }
    @MainActor func testExplicitConfirmOccupancyAndIndependentNextChallenge() {
        let app = launch()
        XCTAssertEqual(app.staticTexts["challenges.version"].label,"Version B")
        tap(app,app.buttons["challenges.review"])
        XCTAssertEqual(app.staticTexts["challenges.confidence"].label,"99% MATCH")
        XCTAssertTrue(app.staticTexts["Suggested match"].exists)
        capture(app,"Flow-B-Proposed-99")
        tap(app,app.buttons["challenges.assistant"])
        XCTAssertTrue(app.staticTexts["challenges.assistant.unavailable"].waitForExistence(timeout:5))
        XCTAssertEqual(app.staticTexts["challenges.confidence"].label,"99% MATCH")
        capture(app,"Flow-B-Assistant-Unavailable-Unconfirmed")
        tap(app,app.buttons["challenges.confirm"])
        XCTAssertEqual(app.staticTexts["challenges.confidence"].label,"88% MATCH")
        XCTAssertTrue(app.staticTexts["Around the World"].exists)
        capture(app,"Flow-E-Independent-World-88")
        tap(app,app.buttons["challenges.confirm"])
        XCTAssertEqual(app.staticTexts["challenges.confidence"].label,"70% MATCH")
        capture(app,"Flow-E-Independent-Monthly-70")
        app.terminate()
    }
    @MainActor func testRejectNextBestAndNoReasonOrRecurrence() {
        let app = launch("review")
        for (score,next) in [(99,88),(88,70)] {
            XCTAssertEqual(app.staticTexts["challenges.confidence"].label,"\(score)% MATCH")
            tap(app,app.buttons["challenges.reject"])
            XCTAssertEqual(app.staticTexts["challenges.confidence"].label,"\(next)% MATCH")
            capture(app,"Flow-C-After-Reject-\(next)")
        }
        tap(app,app.buttons["challenges.reject"])
        XCTAssertTrue(app.staticTexts["No more eligible matches"].waitForExistence(timeout:5))
        XCTAssertFalse(app.textFields.firstMatch.exists)
        XCTAssertFalse(app.buttons["challenges.confirm"].exists)
        capture(app,"Flow-C-No-More-Matches")
        app.terminate()
    }
    @MainActor func testManualAndSameWeekReplacement() {
        var app = launch("tropes")
        tap(app,app.buttons["challenges.assign.prompt.1"])
        tap(app,app.buttons.containing(.staticText,identifier:"The Amber Garden").firstMatch)
        tap(app,app.buttons["challenges.manual.confirm"])
        XCTAssertTrue(app.staticTexts["Manual assignment"].waitForExistence(timeout:5))
        capture(app,"Flow-D-Manual-Confirmed")
        app.terminate()
        app = launch("weeks")
        tap(app,app.buttons["challenges.replace.9"])
        XCTAssertFalse(app.buttons.containing(.staticText,identifier:"Another Week").firstMatch.exists)
        tap(app,app.buttons.containing(.staticText,identifier:"The Blue Notebook").firstMatch)
        capture(app,"Flow-F-Same-Week-Selected")
        tap(app,app.buttons["challenges.manual.confirm"])
        XCTAssertTrue(app.staticTexts["The Blue Notebook"].waitForExistence(timeout:5))
        capture(app,"Flow-F-Week-Replaced")
        app.terminate()
    }
    @MainActor func testChallengesVisualMatrixAndRotation() {
        let routes = ["overview","review","seasonal","tropes","archetype","world","monthly","alphabet","weeks","hundred","roulette","archive","2026","2028","no-information"]
        for (appearance,size) in [("Light","UICTContentSizeCategoryL"),("Dark","UICTContentSizeCategoryL"),("Light","UICTContentSizeCategoryAccessibilityXXXL")] {
            for route in routes {
                let app = launch(route,appearance:appearance,size:size)
                XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout:10))
                capture(app,"\(appearance)-\(size)-\(route)-top")
                app.swipeUp(); capture(app,"\(appearance)-\(size)-\(route)-lower")
                if route == "review" {
                    for score in [88,70] {
                        tap(app,app.buttons["challenges.reject"])
                        XCTAssertEqual(app.staticTexts["challenges.confidence"].label,"\(score)% MATCH")
                        capture(app,"\(appearance)-\(size)-review-\(score)")
                    }
                    tap(app,app.buttons["challenges.reject"])
                    XCTAssertTrue(app.staticTexts["No more eligible matches"].waitForExistence(timeout:5))
                    capture(app,"\(appearance)-\(size)-review-empty")
                }
                if route == "archetype" || route == "monthly" {
                    let label = route == "archetype" ? "Prompt 10 � Not configured" : "Prompt 2 � Not configured"
                    let missing = app.staticTexts[label].firstMatch
                    for _ in 0..<35 where !missing.isHittable { app.swipeUp() }
                    XCTAssertTrue(missing.isHittable, "Unavailable catalog slot must remain visible and unfilled")
                    capture(app,"\(appearance)-\(size)-\(route)-missing-content")
                }
                if route == "2026" || route == "2028" { XCTAssertEqual(app.staticTexts["challenges.version"].label,"Version A") }
                if route == "archive" { XCTAssertTrue(app.buttons["challenges.archived.2026"].exists) }
                if route == "roulette" { XCTAssertTrue(app.staticTexts["Prompts not configured"].exists); XCTAssertFalse(app.buttons["challenges.assign.1"].exists) }
                app.terminate()
            }
        }
    }
}
