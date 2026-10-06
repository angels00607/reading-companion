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
        reveal(app,element)
        XCTAssertTrue(element.exists, "Required live control must exist: \(element.identifier)")
        XCTAssertTrue(element.isHittable, "Control must remain reachable: \(element.identifier)")
        guard element.exists && element.isHittable else { return }
        XCTAssertGreaterThanOrEqual(element.frame.width,44, "Live control width: \(element.identifier), \(element.label), \(element.frame)")
        XCTAssertGreaterThanOrEqual(element.frame.height,44, "Live control height: \(element.identifier), \(element.label), \(element.frame)")
        element.tap()
    }
    @MainActor private func reveal(_ app: XCUIApplication, _ element: XCUIElement) {
        _ = element.waitForExistence(timeout:1)
        let viewport = app.scrollViews.firstMatch.frame.intersection(app.frame).insetBy(dx: 0, dy: 12)
        for _ in 0..<35 {
            if element.exists && element.isHittable && viewport.contains(element.frame) { return }
            if element.exists {
                let movingDown = element.frame.midY < viewport.midY
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: movingDown ? 0.35 : 0.75))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: movingDown ? 0.75 : 0.35))
                start.press(forDuration: 0.05, thenDragTo: end)
            } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable && viewport.contains(element.frame), "Required control must be fully visible: \(element.identifier), \(element.label), \(element.frame), viewport \(viewport)")
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot:app.screenshot()); a.name = "Phase5-" + name; a.lifetime = .keepAlways; add(a)
    }
    @MainActor private func revealTextStart(_ app: XCUIApplication, _ element: XCUIElement) {
        let viewport = app.scrollViews.firstMatch.frame.intersection(app.frame).insetBy(dx: 0, dy: 12)
        for _ in 0..<35 {
            if element.exists && (viewport.contains(element.frame) || (element.frame.height > viewport.height && element.frame.minY >= viewport.minY && element.frame.minY <= viewport.midY)) { return }
            let movingDown = element.exists && element.frame.minY < viewport.minY
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: movingDown ? 0.4 : 0.65))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: movingDown ? 0.6 : 0.45))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.exists && (viewport.contains(element.frame) || (element.frame.height > viewport.height && element.frame.minY >= viewport.minY && element.frame.minY <= viewport.midY)), "Scrollable text must expose its start: \(element.identifier), \(element.frame)")
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
                    reveal(app,app.staticTexts["challenges.confidence"])
                    XCTAssertTrue(app.staticTexts["challenges.confidence"].isHittable)
                    capture(app,"\(appearance)-\(size)-review-99-confidence")
                    reveal(app,app.buttons["challenges.assistant"])
                    XCTAssertTrue(app.buttons["challenges.assistant"].isHittable)
                    XCTAssertGreaterThanOrEqual(app.buttons["challenges.assistant"].frame.width,44)
                    XCTAssertGreaterThanOrEqual(app.buttons["challenges.assistant"].frame.height,44)
                    capture(app,"\(appearance)-\(size)-review-actions")
                    tap(app,app.buttons["challenges.assistant"])
                    let unavailable = app.staticTexts["challenges.assistant.unavailable"]
                    XCTAssertTrue(unavailable.waitForExistence(timeout:5))
                    XCTAssertEqual(app.staticTexts["challenges.confidence"].label,"99% MATCH")
                    revealTextStart(app,unavailable)
                    capture(app,"\(appearance)-\(size)-assistant-unavailable")
                    app.swipeUp()
                    capture(app,"\(appearance)-\(size)-assistant-unavailable-lower")
                    for score in [88,70] {
                        tap(app,app.buttons["challenges.reject"])
                        XCTAssertEqual(app.staticTexts["challenges.confidence"].label,"\(score)% MATCH")
                        reveal(app,app.staticTexts["challenges.confidence"])
                        XCTAssertTrue(app.staticTexts["challenges.confidence"].isHittable)
                        capture(app,"\(appearance)-\(size)-review-\(score)")
                    }
                    tap(app,app.buttons["challenges.reject"])
                    XCTAssertTrue(app.staticTexts["No more eligible matches"].waitForExistence(timeout:5))
                    capture(app,"\(appearance)-\(size)-review-empty")
                }
                if route == "archetype" || route == "monthly" {
                    let label = route == "archetype" ? "Prompt 10 · Not configured" : "Prompt 2 · Not configured"
                    let missing = app.staticTexts[label].firstMatch
                    reveal(app,missing)
                    XCTAssertTrue(missing.isHittable, "Unavailable catalog slot must remain visible and unfilled")
                    if route == "monthly" { XCTAssertTrue(app.staticTexts["December"].exists) }
                    capture(app,"\(appearance)-\(size)-\(route)-missing-content")
                }
                if route == "2026" || route == "2028" { XCTAssertEqual(app.staticTexts["challenges.version"].label,"Version A") }
                if route == "archive" {
                    tap(app,app.buttons["challenges.archived.2026"])
                    XCTAssertEqual(app.staticTexts["challenges.year"].label,"2026")
                    XCTAssertEqual(app.staticTexts["challenges.version"].label,"Version A")
                    XCTAssertTrue(app.scrollViews.firstMatch.exists)
                    capture(app,"\(appearance)-\(size)-archive-2026-open")
                }
                if route == "roulette" { XCTAssertTrue(app.staticTexts["Prompts not configured"].exists); XCTAssertFalse(app.buttons["challenges.assign.1"].exists) }
                if route == "tropes" {
                    tap(app,app.buttons["challenges.assign.prompt.1"])
                    tap(app,app.buttons.containing(.staticText,identifier:"The Amber Garden").firstMatch)
                    capture(app,"\(appearance)-\(size)-manual-selection")
                    tap(app,app.buttons["challenges.manual.confirm"])
                    XCTAssertTrue(app.staticTexts["Manual assignment"].waitForExistence(timeout:5))
                    reveal(app,app.staticTexts["Manual assignment"].firstMatch)
                    capture(app,"\(appearance)-\(size)-manual-confirmed")
                }
                if route == "weeks" {
                    tap(app,app.buttons["challenges.replace.9"])
                    tap(app,app.buttons.containing(.staticText,identifier:"The Blue Notebook").firstMatch)
                    capture(app,"\(appearance)-\(size)-same-week-selection")
                    tap(app,app.buttons["challenges.manual.confirm"])
                    XCTAssertTrue(app.staticTexts["The Blue Notebook"].waitForExistence(timeout:5))
                    reveal(app,app.staticTexts["The Blue Notebook"].firstMatch)
                    capture(app,"\(appearance)-\(size)-same-week-confirmed")
                }
                app.terminate()
            }
        }
    }
}
